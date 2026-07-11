package com.footverse.order.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;

import com.footverse.address.service.AddressService;
import com.footverse.cart.dto.CheckoutCartLine;
import com.footverse.cart.service.CartService;
import com.footverse.common.dto.PageResponse;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.ResourceNotFoundException;
import com.footverse.common.security.CurrentUserProvider;
import com.footverse.order.dto.CouponPreviewRequest;
import com.footverse.order.dto.CouponPreviewResponse;
import com.footverse.order.dto.OrderDetailResponse;
import com.footverse.order.dto.OrderItemResponse;
import com.footverse.order.dto.OrderSummaryResponse;
import com.footverse.order.entity.Coupon;
import com.footverse.order.entity.DiscountType;
import com.footverse.order.entity.Order;
import com.footverse.order.entity.OrderItem;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;
import com.footverse.order.mapper.CouponMapper;
import com.footverse.order.mapper.OrderMapper;
import com.footverse.order.repository.CouponRepository;
import com.footverse.order.repository.OrderItemRepository;
import com.footverse.order.repository.OrderRepository;
import com.footverse.product.dto.ProductVariantPurchaseSnapshot;
import com.footverse.product.service.ProductVariantService;
import com.footverse.user.entity.User;

/**
 * Unit tests for the {@link OrderServiceImpl} checkout preview ({@code previewCoupon}): the
 * server-computed pricing, the coupon-validation matrix, the {@code PERCENT}/{@code FIXED} discount
 * computation (including the percentage cap), the propagated cart ownership errors, and the read-only
 * guarantee (no coupon/stock/cart mutation, and the plain — not locking — cart resolution).
 */
@ExtendWith(MockitoExtension.class)
class OrderServiceImplTest {

    private static final Long CART_ITEM_ID = 10L;
    private static final Long VARIANT_ID = 7L;
    private static final BigDecimal SHIPPING_FEE = new BigDecimal("30000.00");

    @Mock
    private CouponRepository couponRepository;

    @Mock
    private CouponMapper couponMapper;

    @Mock
    private CartService cartService;

    @Mock
    private ProductVariantService productVariantService;

    @Mock
    private AddressService addressService;

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private OrderItemRepository orderItemRepository;

    @Mock
    private OrderMapper orderMapper;

    @Mock
    private CurrentUserProvider currentUserProvider;

    private OrderServiceImpl service;

    private void init() {
        service = new OrderServiceImpl(couponRepository, couponMapper, cartService, productVariantService,
                addressService, orderRepository, orderItemRepository, orderMapper, currentUserProvider);
    }

    private CouponPreviewRequest request(String code) {
        return new CouponPreviewRequest(code, List.of(CART_ITEM_ID));
    }

    /**
     * Stubs the selected cart line ({@code quantity}) and its variant snapshot ({@code unitPrice}) so
     * the subtotal is {@code unitPrice × quantity}.
     */
    private void withLine(int quantity, String unitPrice) {
        when(cartService.resolvePreviewItems(List.of(CART_ITEM_ID)))
                .thenReturn(List.of(new CheckoutCartLine(CART_ITEM_ID, VARIANT_ID, quantity)));
        when(productVariantService.getPurchaseSnapshot(VARIANT_ID)).thenReturn(
                new ProductVariantPurchaseSnapshot(VARIANT_ID, 100L, "Air Force 1", "img.png", "Black", "42",
                        new BigDecimal(unitPrice), 50, true));
    }

    private Coupon coupon(DiscountType type, String discountValue, String minOrder, String maxDiscount,
            boolean enabled, LocalDateTime start, LocalDateTime end, Integer usageLimit, int usedCount) {
        Coupon coupon = new Coupon();
        coupon.setCode("SAVE");
        coupon.setName("Save Now");
        coupon.setDiscountType(type);
        coupon.setDiscountValue(new BigDecimal(discountValue));
        coupon.setMinOrderAmount(new BigDecimal(minOrder));
        coupon.setMaxDiscountAmount(maxDiscount == null ? null : new BigDecimal(maxDiscount));
        coupon.setStartAt(start);
        coupon.setEndAt(end);
        coupon.setUsageLimit(usageLimit);
        coupon.setUsedCount(usedCount);
        coupon.setEnabled(enabled);
        return coupon;
    }

    private Coupon activeCoupon(DiscountType type, String discountValue, String minOrder, String maxDiscount) {
        return coupon(type, discountValue, minOrder, maxDiscount, true,
                LocalDateTime.now().minusDays(1), LocalDateTime.now().plusDays(1), null, 0);
    }

    private void assertNoMutation() {
        verify(couponRepository, never()).save(any());
        verify(cartService, never()).resolveCheckoutItems(any());
        verify(cartService, never()).removeCheckedOutItems(any());
        verify(productVariantService, never()).decrementStock(any());
    }

    /**
     * A preview without a coupon returns the plain totals: {@code subtotal}, zero discount, the flat
     * shipping fee, and {@code total = subtotal + shippingFee}; {@code code} / {@code name} are null.
     */
    @Test
    void previewWithoutCouponReturnsPlainTotals() {
        init();
        withLine(2, "100.00");

        CouponPreviewResponse response = service.previewCoupon(request(null));

        assertThat(response.code()).isNull();
        assertThat(response.name()).isNull();
        assertThat(response.subtotal()).isEqualByComparingTo("200.00");
        assertThat(response.discountAmount()).isEqualByComparingTo("0");
        assertThat(response.shippingFee()).isEqualByComparingTo(SHIPPING_FEE);
        assertThat(response.total()).isEqualByComparingTo("30200.00");
        verify(cartService).resolvePreviewItems(List.of(CART_ITEM_ID));
        verify(couponRepository, never()).findByCode(any());
        assertNoMutation();
    }

    /**
     * A blank coupon code is treated as no coupon: no lookup, plain totals.
     */
    @Test
    void previewWithBlankCodeIsTreatedAsNoCoupon() {
        init();
        withLine(1, "150.00");

        CouponPreviewResponse response = service.previewCoupon(request("   "));

        assertThat(response.code()).isNull();
        assertThat(response.discountAmount()).isEqualByComparingTo("0");
        assertThat(response.total()).isEqualByComparingTo("30150.00");
        verify(couponRepository, never()).findByCode(any());
    }

    /**
     * A valid PERCENT coupon returns its code/name and a discount of {@code subtotal × percent}.
     */
    @Test
    void previewWithValidPercentCouponComputesDiscount() {
        init();
        withLine(2, "100.00");
        when(couponRepository.findByCode("SAVE"))
                .thenReturn(Optional.of(activeCoupon(DiscountType.PERCENT, "10", "0", null)));

        CouponPreviewResponse response = service.previewCoupon(request("SAVE"));

        assertThat(response.code()).isEqualTo("SAVE");
        assertThat(response.name()).isEqualTo("Save Now");
        assertThat(response.subtotal()).isEqualByComparingTo("200.00");
        assertThat(response.discountAmount()).isEqualByComparingTo("20.00");
        assertThat(response.total()).isEqualByComparingTo("30180.00");
        assertNoMutation();
    }

    /**
     * A PERCENT coupon's discount is capped by {@code maxDiscountAmount} when the raw percentage
     * exceeds it.
     */
    @Test
    void previewWithPercentCouponAppliesMaxDiscountCap() {
        init();
        withLine(2, "100.00");
        when(couponRepository.findByCode("SAVE"))
                .thenReturn(Optional.of(activeCoupon(DiscountType.PERCENT, "10", "0", "15")));

        CouponPreviewResponse response = service.previewCoupon(request("SAVE"));

        assertThat(response.discountAmount()).isEqualByComparingTo("15.00");
        assertThat(response.total()).isEqualByComparingTo("30185.00");
    }

    /**
     * A valid FIXED coupon discounts exactly its {@code discountValue}.
     */
    @Test
    void previewWithValidFixedCouponComputesDiscount() {
        init();
        withLine(2, "100.00");
        when(couponRepository.findByCode("SAVE"))
                .thenReturn(Optional.of(activeCoupon(DiscountType.FIXED, "50", "0", null)));

        CouponPreviewResponse response = service.previewCoupon(request("SAVE"));

        assertThat(response.discountAmount()).isEqualByComparingTo("50");
        assertThat(response.total()).isEqualByComparingTo("30150.00");
    }

    /**
     * A FIXED discount larger than the subtotal is clamped to the subtotal, so the total floors at
     * the shipping fee and never goes negative (project decision — the spec bounds neither
     * {@code discountValue} nor the percentage against the subtotal).
     */
    @Test
    void previewClampsFixedDiscountToSubtotal() {
        init();
        withLine(2, "100.00"); // subtotal 200
        when(couponRepository.findByCode("SAVE"))
                .thenReturn(Optional.of(activeCoupon(DiscountType.FIXED, "500", "0", null)));

        CouponPreviewResponse response = service.previewCoupon(request("SAVE"));

        assertThat(response.discountAmount()).isEqualByComparingTo("200.00");
        assertThat(response.total()).isEqualByComparingTo(SHIPPING_FEE);
    }

    /**
     * A percentage over 100 is likewise clamped to the subtotal before the total is computed.
     */
    @Test
    void previewClampsOverHundredPercentDiscountToSubtotal() {
        init();
        withLine(2, "100.00"); // subtotal 200
        when(couponRepository.findByCode("SAVE"))
                .thenReturn(Optional.of(activeCoupon(DiscountType.PERCENT, "200", "0", null)));

        CouponPreviewResponse response = service.previewCoupon(request("SAVE"));

        assertThat(response.discountAmount()).isEqualByComparingTo("200.00");
        assertThat(response.total()).isEqualByComparingTo(SHIPPING_FEE);
    }

    /**
     * An unknown coupon code reuses the existing {@code 404 COUPON_NOT_FOUND}.
     */
    @Test
    void previewWithUnknownCouponIsNotFound() {
        init();
        withLine(1, "100.00");
        when(couponRepository.findByCode("SAVE")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.previewCoupon(request("SAVE")))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "COUPON_NOT_FOUND")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.NOT_FOUND);
        assertNoMutation();
    }

    /**
     * A disabled coupon is rejected with {@code 400 COUPON_DISABLED}.
     */
    @Test
    void previewWithDisabledCouponIsRejected() {
        init();
        withLine(1, "100.00");
        Coupon disabled = coupon(DiscountType.FIXED, "10", "0", null, false,
                LocalDateTime.now().minusDays(1), LocalDateTime.now().plusDays(1), null, 0);
        when(couponRepository.findByCode("SAVE")).thenReturn(Optional.of(disabled));

        assertThatThrownBy(() -> service.previewCoupon(request("SAVE")))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "COUPON_DISABLED")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.BAD_REQUEST);
        assertNoMutation();
    }

    /**
     * A coupon outside its {@code [startAt, endAt]} window is rejected with {@code 400 COUPON_EXPIRED}.
     */
    @Test
    void previewWithExpiredCouponIsRejected() {
        init();
        withLine(1, "100.00");
        Coupon expired = coupon(DiscountType.FIXED, "10", "0", null, true,
                LocalDateTime.now().minusDays(5), LocalDateTime.now().minusDays(1), null, 0);
        when(couponRepository.findByCode("SAVE")).thenReturn(Optional.of(expired));

        assertThatThrownBy(() -> service.previewCoupon(request("SAVE")))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "COUPON_EXPIRED")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.BAD_REQUEST);
    }

    /**
     * A coupon whose usage limit is reached is rejected with {@code 400 COUPON_USAGE_LIMIT_EXCEEDED}.
     */
    @Test
    void previewWithUsageLimitExceededIsRejected() {
        init();
        withLine(1, "100.00");
        Coupon exhausted = coupon(DiscountType.FIXED, "10", "0", null, true,
                LocalDateTime.now().minusDays(1), LocalDateTime.now().plusDays(1), 5, 5);
        when(couponRepository.findByCode("SAVE")).thenReturn(Optional.of(exhausted));

        assertThatThrownBy(() -> service.previewCoupon(request("SAVE")))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "COUPON_USAGE_LIMIT_EXCEEDED")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.BAD_REQUEST);
    }

    /**
     * A subtotal below the coupon's minimum order amount is rejected with
     * {@code 400 COUPON_MIN_ORDER_AMOUNT_NOT_MET}.
     */
    @Test
    void previewWithSubtotalBelowMinimumIsRejected() {
        init();
        withLine(2, "100.00"); // subtotal 200
        when(couponRepository.findByCode("SAVE"))
                .thenReturn(Optional.of(activeCoupon(DiscountType.FIXED, "10", "500", null)));

        assertThatThrownBy(() -> service.previewCoupon(request("SAVE")))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "COUPON_MIN_ORDER_AMOUNT_NOT_MET")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.BAD_REQUEST);
        assertNoMutation();
    }

    /**
     * A cart item that belongs to another user surfaces the cart service's {@code 403
     * CART_ITEM_FORBIDDEN}; no coupon lookup or mutation happens.
     */
    @Test
    void previewWithForeignCartItemIsForbidden() {
        init();
        when(cartService.resolvePreviewItems(List.of(CART_ITEM_ID)))
                .thenThrow(new BusinessException(HttpStatus.FORBIDDEN, "CART_ITEM_FORBIDDEN",
                        "You cannot access this cart item"));

        assertThatThrownBy(() -> service.previewCoupon(request("SAVE")))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "CART_ITEM_FORBIDDEN")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.FORBIDDEN);
        verify(couponRepository, never()).findByCode(any());
        assertNoMutation();
    }

    /**
     * A cart item that does not exist surfaces the cart service's {@code 404 CART_ITEM_NOT_FOUND}.
     */
    @Test
    void previewWithUnknownCartItemIsNotFound() {
        init();
        when(cartService.resolvePreviewItems(List.of(CART_ITEM_ID)))
                .thenThrow(new ResourceNotFoundException("CART_ITEM_NOT_FOUND", "Cart item not found"));

        assertThatThrownBy(() -> service.previewCoupon(request(null)))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "CART_ITEM_NOT_FOUND");
        assertNoMutation();
    }

    // ----- Customer order queries (getMyOrders / getMyOrder) -----

    private static final Long USER_ID = 1L;

    private User caller() {
        User user = new User();
        user.setId(USER_ID);
        return user;
    }

    private Order order(Long id) {
        Order order = new Order();
        order.setId(id);
        order.setOrderCode("FV-ORDER-" + id);
        order.setStatus(OrderStatus.PENDING);
        order.setPaymentMethod(PaymentMethod.COD);
        order.setPaymentStatus(PaymentStatus.UNPAID);
        order.setTotal(new BigDecimal("30200.00"));
        return order;
    }

    private OrderItem orderLine(Order order, int quantity) {
        OrderItem item = new OrderItem();
        item.setOrder(order);
        item.setQuantity(quantity);
        return item;
    }

    private OrderSummaryResponse summary(int itemCount) {
        return new OrderSummaryResponse(5L, "FV-ORDER-5", OrderStatus.PENDING, PaymentStatus.UNPAID,
                new BigDecimal("30200.00"), itemCount, LocalDateTime.now());
    }

    /**
     * The order history is caller-scoped: the list is read for the authenticated user's id resolved
     * through {@link CurrentUserProvider}, never a client-supplied id.
     */
    @Test
    void getMyOrdersReadsOnlyTheCallersOrders() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(caller());
        Order order = order(5L);
        when(orderRepository.findByUserId(eq(USER_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(order)));
        when(orderItemRepository.findByOrderIdIn(List.of(5L)))
                .thenReturn(List.of(orderLine(order, 2), orderLine(order, 3)));
        when(orderMapper.toSummaryResponse(eq(order), anyInt())).thenReturn(summary(5));

        PageResponse<OrderSummaryResponse> page = service.getMyOrders(PageRequest.of(0, 20));

        assertThat(page.content()).hasSize(1);
        verify(orderRepository).findByUserId(eq(USER_ID), any(Pageable.class));
    }

    /**
     * {@code itemCount} is the sum of the order-item quantities (Σ quantity), computed by the service
     * from a single batch read — not a stored column.
     */
    @Test
    void getMyOrdersComputesItemCountAsSumOfQuantities() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(caller());
        Order order = order(5L);
        when(orderRepository.findByUserId(eq(USER_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(order)));
        when(orderItemRepository.findByOrderIdIn(List.of(5L)))
                .thenReturn(List.of(orderLine(order, 2), orderLine(order, 3)));
        when(orderMapper.toSummaryResponse(eq(order), anyInt())).thenReturn(summary(5));

        service.getMyOrders(PageRequest.of(0, 20));

        ArgumentCaptor<Integer> itemCount = ArgumentCaptor.forClass(Integer.class);
        verify(orderMapper).toSummaryResponse(eq(order), itemCount.capture());
        assertThat(itemCount.getValue()).isEqualTo(5);
    }

    /**
     * The list is always ordered {@code createdAt} descending: the service preserves the client's
     * page and size but overrides any client-supplied sort (assumption 3).
     */
    @Test
    void getMyOrdersForcesCreatedAtDescendingSort() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(caller());
        when(orderRepository.findByUserId(eq(USER_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        service.getMyOrders(PageRequest.of(2, 15, Sort.by(Sort.Direction.ASC, "total")));

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(orderRepository).findByUserId(eq(USER_ID), pageable.capture());
        Pageable used = pageable.getValue();
        assertThat(used.getPageNumber()).isEqualTo(2);
        assertThat(used.getPageSize()).isEqualTo(15);
        Sort.Order createdAt = used.getSort().getOrderFor("createdAt");
        assertThat(createdAt).isNotNull();
        assertThat(createdAt.getDirection()).isEqualTo(Sort.Direction.DESC);
        assertThat(used.getSort().getOrderFor("total")).isNull();
    }

    /**
     * With no orders on the page, the service skips the item-count batch query entirely.
     */
    @Test
    void getMyOrdersWithNoOrdersSkipsItemCountQuery() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(caller());
        when(orderRepository.findByUserId(eq(USER_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        PageResponse<OrderSummaryResponse> page = service.getMyOrders(PageRequest.of(0, 20));

        assertThat(page.content()).isEmpty();
        verify(orderItemRepository, never()).findByOrderIdIn(any());
    }

    /**
     * The detail is assembled entirely from the persisted order and its item snapshots (including the
     * post-migration {@code color}); the service reads the caller-scoped order and maps its lines.
     */
    @Test
    void getMyOrderReturnsDetailAssembledFromSnapshots() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(caller());
        Order order = order(9L);
        OrderItem line = orderLine(order, 2);
        when(orderRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(order));
        when(orderItemRepository.findByOrderId(9L)).thenReturn(List.of(line));
        OrderItemResponse itemResponse = new OrderItemResponse(1L, 7L, "Air Force 1", "img.png", "Black",
                "42", new BigDecimal("100.00"), 2, new BigDecimal("200.00"));
        when(orderMapper.toResponse(line)).thenReturn(itemResponse);
        OrderDetailResponse detail = new OrderDetailResponse(9L, "FV-ORDER-9", OrderStatus.PENDING,
                PaymentMethod.COD, PaymentStatus.UNPAID, new BigDecimal("200.00"), BigDecimal.ZERO,
                new BigDecimal("30000.00"), new BigDecimal("30200.00"), null, "Jane", "0900000000", "HCM",
                "D1", "W1", "1 Street", null, List.of(itemResponse), LocalDateTime.now(), null, null);
        when(orderMapper.toDetailResponse(order, List.of(itemResponse))).thenReturn(detail);

        OrderDetailResponse result = service.getMyOrder(9L);

        assertThat(result).isSameAs(detail);
        assertThat(result.items()).singleElement()
                .satisfies(item -> assertThat(item.color()).isEqualTo("Black"));
        verify(orderMapper).toResponse(line);
    }

    /**
     * An order that exists but belongs to another user is the ownership {@code 403 ORDER_FORBIDDEN} —
     * never hidden behind a {@code 404} (address / cart precedent).
     */
    @Test
    void getMyOrderOfAnotherUserIsForbidden() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(caller());
        when(orderRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.empty());
        when(orderRepository.existsById(9L)).thenReturn(true);

        assertThatThrownBy(() -> service.getMyOrder(9L))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "ORDER_FORBIDDEN")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.FORBIDDEN);
    }

    /**
     * An order that does not exist at all is the {@code 404 ORDER_NOT_FOUND}.
     */
    @Test
    void getMyOrderThatDoesNotExistIsNotFound() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(caller());
        when(orderRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.empty());
        when(orderRepository.existsById(9L)).thenReturn(false);

        assertThatThrownBy(() -> service.getMyOrder(9L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "ORDER_NOT_FOUND")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.NOT_FOUND);
    }
}
