package com.footverse.order.service;

import java.util.Map;

import org.springframework.data.domain.Pageable;

import com.footverse.common.dto.PageResponse;
import com.footverse.order.dto.AdminOrderDetailResponse;
import com.footverse.order.dto.AdminOrderSummaryResponse;
import com.footverse.order.dto.CouponPreviewRequest;
import com.footverse.order.dto.DashboardResponse;
import com.footverse.order.dto.CouponPreviewResponse;
import com.footverse.order.dto.CouponResponse;
import com.footverse.order.dto.CreateCouponRequest;
import com.footverse.order.dto.OrderDetailResponse;
import com.footverse.order.dto.OrderSummaryResponse;
import com.footverse.order.dto.PaymentUrlResponse;
import com.footverse.order.dto.PlaceOrderRequest;
import com.footverse.order.dto.UpdateCouponRequest;
import com.footverse.order.dto.UpdateOrderStatusRequest;
import com.footverse.order.dto.VnpayReturnResponse;
import com.footverse.order.entity.OrderStatus;

/**
 * Single service of the {@code order} module. It owns all order-related logic, including the coupon
 * concern, which lives here rather than in a standalone service (architecture-spec §4, §13). Admin
 * order operations live here too — there is no {@code OrderAdminService}
 * (architecture-spec §20, sprint-12-plan Design Decision 3).
 *
 * <p>This sprint delivers the admin coupon CRUD, the read-only checkout preview, the transactional
 * checkout, the caller-scoped order queries, customer cancellation, the admin order-status machine,
 * and the admin order read surface (sprint-12-plan Task 01). Sprint 13 Task 01 adds the ADMIN
 * dashboard's aggregate read; Sprint 13 Task 09 adds the VNPay sandbox payment operations — no
 * separate {@code StatisticsService} or {@code PaymentService} (architecture-spec §20).</p>
 */
public interface OrderService {

    /**
     * Returns a page of coupons for admin management.
     *
     * @param pageable the pagination and sort request
     * @return the page of coupon responses
     */
    PageResponse<CouponResponse> getCoupons(Pageable pageable);

    /**
     * Creates a new coupon. The code must be unique across all coupons and {@code endAt} must be
     * after {@code startAt}.
     *
     * @param request the validated create payload
     * @return the created coupon
     */
    CouponResponse createCoupon(CreateCouponRequest request);

    /**
     * Updates an existing coupon. The new code must not collide with a different coupon and
     * {@code endAt} must be after {@code startAt}; {@code usedCount} is preserved.
     *
     * @param id      the id of the coupon to update
     * @param request the validated update payload
     * @return the updated coupon
     */
    CouponResponse updateCoupon(Long id, UpdateCouponRequest request);

    /**
     * Computes the checkout preview for the caller's selected cart items, optionally applying a
     * coupon (business-rules → Checkout Preview). Prices the selected lines, validates and applies
     * the coupon when a code is supplied, adds the flat shipping fee, and returns the fully
     * server-computed summary ({@code subtotal / discountAmount / shippingFee / total}). This is a
     * read-only operation: it mutates nothing — no {@code usedCount} increment, no stock or cart
     * change (sprint-4-plan item 08).
     *
     * @param request the preview request (selected cart item ids and an optional coupon code)
     * @return the server-computed checkout summary
     * @throws com.footverse.common.exception.BusinessException {@code 403 CART_ITEM_FORBIDDEN} for
     *         another user's cart item, or {@code 400} for a coupon that is not applicable
     *         ({@code COUPON_DISABLED} / {@code COUPON_EXPIRED} /
     *         {@code COUPON_USAGE_LIMIT_EXCEEDED} / {@code COUPON_MIN_ORDER_AMOUNT_NOT_MET})
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404} for an unknown
     *         cart item ({@code CART_ITEM_NOT_FOUND}) or coupon code ({@code COUPON_NOT_FOUND})
     */
    CouponPreviewResponse previewCoupon(CouponPreviewRequest request);

    /**
     * Places an order from the caller's selected cart items — the single transactional checkout
     * write (business-rules → Checkout; database-spec §17). In one transaction it resolves and
     * ownership-checks the selected cart lines (under a row lock so two concurrent checkouts cannot
     * both consume them), resolves and ownership-checks the shipping address, re-runs the shared
     * pricing and coupon-validation path (so the persisted totals match the preview), decrements
     * stock per variant under lock, increments the coupon's {@code usedCount} when one is applied,
     * builds the order and its lines from the variant purchase snapshots, generates the timestamp
     * order code, and removes exactly the checked-out cart lines (the cart row and unselected lines
     * remain — partial checkout). Any failure rolls the whole transaction back with no side effect.
     *
     * <p>Locks are acquired in one fixed order — the selected cart rows first, then the product
     * variants, each in ascending id — so concurrent checkouts cannot deadlock; the loser of a
     * contested selection blocks until the winner commits and then resolves to
     * {@code 404 CART_ITEM_NOT_FOUND} before touching stock, coupon, or order state (Checkout
     * Concurrency Protection, architecture-spec §19).</p>
     *
     * @param request the validated checkout payload
     * @return the created order with its checkout snapshots
     * @throws com.footverse.common.exception.BusinessException {@code 403 CART_ITEM_FORBIDDEN} /
     *         {@code 403 ADDRESS_FORBIDDEN} for a foreign cart item or address; {@code 400}
     *         {@code PRODUCT_VARIANT_INACTIVE} / {@code PRODUCT_VARIANT_INSUFFICIENT_STOCK} for an
     *         unpurchasable variant; {@code 400} for a coupon that is not applicable
     *         ({@code COUPON_DISABLED} / {@code COUPON_EXPIRED} /
     *         {@code COUPON_USAGE_LIMIT_EXCEEDED} / {@code COUPON_MIN_ORDER_AMOUNT_NOT_MET});
     *         {@code 500 ORDER_CODE_GENERATION_FAILED} when a unique order code cannot be generated
     *         within the bounded retry
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404} for an unknown
     *         cart item ({@code CART_ITEM_NOT_FOUND}), address ({@code ADDRESS_NOT_FOUND}), variant
     *         ({@code PRODUCT_VARIANT_NOT_FOUND}), or coupon code ({@code COUPON_NOT_FOUND})
     */
    OrderDetailResponse placeOrder(PlaceOrderRequest request);

    /**
     * Returns a page of the current caller's orders for their order history, most-recent-first
     * ({@code createdAt} descending, sprint-4-plan assumption 3 — the ordering is enforced by the
     * service regardless of any client-supplied sort). The list is caller-scoped (security-spec §7):
     * only the authenticated user's own orders are returned. Each {@link OrderSummaryResponse}
     * carries {@code itemCount}, the sum of its order-item quantities, computed by the service (never
     * read from a stored column).
     *
     * @param pageable the pagination request (its page and size are honoured; the sort is overridden
     *                 with {@code createdAt} descending)
     * @return the caller's page of order summaries, newest first
     */
    PageResponse<OrderSummaryResponse> getMyOrders(Pageable pageable);

    /**
     * Returns one of the caller's orders in full detail, ownership-checked (security-spec §7). The
     * response is assembled entirely from the persisted order and order-item snapshots — product
     * name, image, color, size, unit price, money, and shipping are read as stored at checkout and
     * never recomputed from the current catalog (database-spec §12).
     *
     * @param id the order id
     * @return the caller's order with its checkout snapshots
     * @throws com.footverse.common.exception.BusinessException {@code 403 ORDER_FORBIDDEN} when the
     *         order exists but belongs to another user
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 ORDER_NOT_FOUND}
     *         when no order has the given id
     */
    OrderDetailResponse getMyOrder(Long id);

    /**
     * Reports whether the current caller has at least one {@code DELIVERED} order containing a
     * variant of the given product — the one order-domain fact the review module needs to gate a
     * review (business-rules → Review; database-spec §15), exposed here so {@code ReviewService}
     * never reaches into order rows (architecture-spec §8). This is a caller-scoped read resolved
     * through {@link com.footverse.common.security.CurrentUserProvider} (security-spec §7): it takes
     * no client-supplied user id and answers only for the authenticated user.
     *
     * <p>The name states an <em>order</em> capability, not a review policy: whether this fact grants
     * a review is the review module's decision, deliberately kept out of the order module so the
     * ownership boundary stays sharp (sprint-5-plan item 03). The product's variant ids are resolved
     * through the {@link com.footverse.product.service.ProductVariantService} dependency this service
     * already has; a product with no variants — including an unknown product id, which simply has no
     * variants — is not eligible and yields {@code false}, never an exception. The read mutates
     * nothing.</p>
     *
     * @param productId the product to check for a delivered purchase
     * @return {@code true} when a {@code DELIVERED} order of the caller contains a variant of the
     *         product; {@code false} for no order, a non-{@code DELIVERED} status, another user's
     *         order, or a variant-less / unknown product
     */
    boolean hasDeliveredOrderForProduct(Long productId);

    /**
     * Cancels one of the caller's orders, ownership-checked, with full compensation
     * (business-rules → Cancellation; database-spec §18). Cancellation is allowed only while the
     * order is {@code PENDING}; any other status is rejected with the enveloped
     * {@code 409 ORDER_NOT_CANCELLABLE} and changes nothing.
     *
     * <p>On a {@code PENDING} order, inside one transaction, the service sets the status to
     * {@code CANCELLED}, records {@code cancelledAt}, restores every order item's stock
     * ({@link com.footverse.product.service.ProductVariantService#restoreStock}), and — only when the
     * order applied a coupon — decrements that coupon's {@code usedCount} by one (never below zero).
     * The payment status is left {@code UNPAID}. Any failure rolls the whole compensation back, so no
     * partial state (stock restored but order not cancelled, or coupon rolled back but stock not) can
     * ever persist.</p>
     *
     * @param id the order id
     * @return the cancelled order with its checkout snapshots
     * @throws com.footverse.common.exception.BusinessException {@code 403 ORDER_FORBIDDEN} when the
     *         order exists but belongs to another user, or {@code 409 ORDER_NOT_CANCELLABLE} when the
     *         order is not {@code PENDING}
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 ORDER_NOT_FOUND}
     *         when no order has the given id
     */
    OrderDetailResponse cancelMyOrder(Long id);

    /**
     * Advances an order's status as an admin, enforcing the frozen state machine (business-rules →
     * Order Status Transitions; dto-spec §17). This is an admin operation: it bypasses the ownership
     * check (any order may be advanced regardless of owner, security-spec §7) and resolves the order
     * by id alone.
     *
     * <p>Only these transitions are legal: {@code PENDING→CONFIRMED}, {@code CONFIRMED→SHIPPING},
     * {@code SHIPPING→DELIVERED}, and {@code PENDING→CANCELLED}; any other target is rejected with the
     * enveloped {@code 409} and changes nothing. Marking an order {@code DELIVERED} also flips its
     * payment to {@code PAID} and records {@code deliveredAt} exactly once (business-rules → Payment).
     * An admin {@code PENDING→CANCELLED} runs the <em>same</em> compensation as a customer
     * cancellation — status {@code CANCELLED} + {@code cancelledAt}, stock restore, and coupon
     * {@code usedCount} decrement, all in one transaction — reusing that single cancellation path
     * (there are not two).</p>
     *
     * @param id      the order id
     * @param request the validated target status
     * @return the updated order with its checkout snapshots
     * @throws com.footverse.common.exception.BusinessException {@code 409 ORDER_NOT_CANCELLABLE} when
     *         the target is {@code CANCELLED} but the order is not {@code PENDING}, or
     *         {@code 409 ORDER_INVALID_STATUS_TRANSITION} for any other transition the machine forbids
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 ORDER_NOT_FOUND}
     *         when no order has the given id
     */
    OrderDetailResponse updateOrderStatus(Long id, UpdateOrderStatusRequest request);

    /**
     * Returns a page of orders for ADMIN management, most-recent-first, optionally filtered by
     * {@code status} and/or searched by an {@code orderCode} fragment (contains match) — the read
     * surface that closes the contract gap blocking order administration (dto-spec §15,
     * sprint-12-plan Task 01). This is an admin operation: it performs <strong>no</strong> ownership
     * check (security-spec §7 — ADMIN endpoints bypass ownership) and returns orders across every
     * customer. A blank {@code orderCode} is normalised to "no search" here, so the repository never
     * receives one; the sort is forced to {@code createdAt} descending, exactly as
     * {@link #getMyOrders(Pageable)}.
     *
     * @param status    the status to filter by, or {@code null} for every status
     * @param orderCode the order-code fragment to search for (contains match), or {@code null}/blank
     *                  for no search
     * @param pageable  the pagination request (its page and size are honoured; the sort is overridden
     *                  with {@code createdAt} descending)
     * @return the page of matching orders, each carrying the owning customer's identity, newest first
     */
    PageResponse<AdminOrderSummaryResponse> adminListOrders(OrderStatus status, String orderCode, Pageable pageable);

    /**
     * Returns one order in full detail for ADMIN, resolved by id alone (dto-spec §15,
     * sprint-12-plan Task 01). This is an admin operation: it performs <strong>no</strong> ownership
     * check (security-spec §7) — any order may be read regardless of owner. The response carries the
     * owning customer's account identity alongside the same checkout snapshots
     * {@link #getMyOrder(Long)} returns.
     *
     * @param id the order id
     * @return the order's full detail, carrying the owning customer's identity
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 ORDER_NOT_FOUND}
     *         when no order has the given id
     */
    AdminOrderDetailResponse adminGetOrder(Long id);

    /**
     * Assembles the ADMIN dashboard's core operating figures (dto-spec §15, Sprint 13 Task 01): total
     * revenue and gross profit over {@code DELIVERED} orders, the order count by status (zero-filled
     * to all five {@link OrderStatus} values), the trailing twelve-month revenue series (zero-filled),
     * the top five best-selling products (folded from variant to product), and the five most recent
     * orders. Every figure is computed on read from {@code orders} / {@code order_item} — nothing is
     * stored, cached, or scheduled (architecture-spec §20). The endpoint takes no parameters and every
     * window is fixed; there is no date range, filter, or comparison period.
     *
     * <p>{@code grossProfit} sums only lines with a known unit cost: a line whose
     * {@code unitCostPrice} predates the Sprint 12 snapshot is <strong>excluded</strong>, never
     * coerced to zero (Design Decision 2) — the response's {@code profitLinesWithCost} /
     * {@code profitLinesTotal} report the resulting coverage.</p>
     *
     * @return the assembled dashboard response
     */
    DashboardResponse getDashboard();

    /**
     * Requests a signed VNPay sandbox payment URL for one of the caller's orders (business-rules →
     * Payment; database-spec §10.17; Sprint 13 Task 09), ownership-checked (security-spec §7). The
     * order must be {@code PENDING}, {@code UNPAID}, and {@code paymentMethod = VNPAY} — a {@code COD}
     * order, an already-paid order, or a non-{@code PENDING} order are all rejected with the same code
     * (error-spec §8.15). Any existing {@code PENDING} transaction for the order is superseded (marked
     * {@code FAILED}) rather than reused, so a retried payment always creates a fresh transaction and
     * the attempt history stays complete (database-spec §10.17, Design Decision 7).
     *
     * @param orderId the order to request payment for
     * @return the signed payment URL, its transaction reference, and its expiry
     * @throws com.footverse.common.exception.BusinessException {@code 403 ORDER_FORBIDDEN} when the
     *         order exists but belongs to another user, or
     *         {@code 409 PAYMENT_NOT_APPLICABLE} unless the order is {@code PENDING}, {@code UNPAID},
     *         and {@code paymentMethod = VNPAY}
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 ORDER_NOT_FOUND}
     *         when no order has the given id
     */
    PaymentUrlResponse createPaymentUrl(Long orderId);

    /**
     * Processes the VNPay sandbox gateway's signed return callback (business-rules → Payment;
     * Sprint 13 Task 09) — the <strong>only</strong> path allowed to set {@code paymentStatus = PAID}
     * outside the frozen {@code DELIVERED} side effect. The signature is verified <strong>before any
     * other parameter is read</strong> (Design Decision 6): an invalid, tampered, or absent
     * {@code vnp_SecureHash} is {@code 400 PAYMENT_SIGNATURE_INVALID} and nothing is written. The
     * transaction is then resolved by {@code vnp_TxnRef} ({@code 404
     * PAYMENT_TRANSACTION_NOT_FOUND} when unknown). A transaction already resolved (a prior
     * {@code SUCCESS} or {@code FAILED}) is a no-op replay: nothing is written and the same response
     * is returned, making the handler safe to call twice. Otherwise the returned amount is re-checked
     * against the transaction's stored amount ({@code 400 PAYMENT_AMOUNT_MISMATCH} when it differs,
     * writing nothing); a matching amount then marks the transaction {@code SUCCESS} (recording
     * {@code providerTxnNo}, {@code responseCode}, {@code paidAt}) and flips the order's
     * {@code paymentStatus} to {@code PAID}, or marks it {@code FAILED} and leaves the order untouched.
     *
     * @param params the gateway's {@code vnp_*} return parameters, including {@code vnp_SecureHash}
     * @return the payment outcome for the resolved order
     * @throws com.footverse.common.exception.BusinessException {@code 400 PAYMENT_SIGNATURE_INVALID}
     *         for a signature that does not verify, or {@code 400 PAYMENT_AMOUNT_MISMATCH} for a
     *         returned amount that does not match the stored transaction
     * @throws com.footverse.common.exception.ResourceNotFoundException
     *         {@code 404 PAYMENT_TRANSACTION_NOT_FOUND} when no transaction has the given
     *         {@code vnp_TxnRef}
     */
    VnpayReturnResponse handleVnpayReturn(Map<String, String> params);
}
