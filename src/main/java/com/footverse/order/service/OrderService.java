package com.footverse.order.service;

import org.springframework.data.domain.Pageable;

import com.footverse.common.dto.PageResponse;
import com.footverse.order.dto.CouponPreviewRequest;
import com.footverse.order.dto.CouponPreviewResponse;
import com.footverse.order.dto.CouponResponse;
import com.footverse.order.dto.CreateCouponRequest;
import com.footverse.order.dto.OrderDetailResponse;
import com.footverse.order.dto.PlaceOrderRequest;
import com.footverse.order.dto.UpdateCouponRequest;

/**
 * Single service of the {@code order} module. It owns all order-related logic, including the coupon
 * concern, which lives here rather than in a standalone service (architecture-spec §4, §13).
 *
 * <p>This sprint delivers the admin coupon CRUD, the read-only checkout preview, and the
 * transactional checkout; cancellation, order queries, and admin status updates are added by later
 * tasks.</p>
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
}
