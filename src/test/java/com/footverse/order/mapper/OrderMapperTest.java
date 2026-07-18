package com.footverse.order.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.footverse.order.dto.AdminOrderDetailResponse;
import com.footverse.order.dto.AdminOrderSummaryResponse;
import com.footverse.order.dto.OrderItemResponse;
import com.footverse.order.entity.Coupon;
import com.footverse.order.entity.Order;
import com.footverse.order.entity.OrderItem;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;
import com.footverse.user.entity.User;

/**
 * Unit test for the generated {@link OrderMapper}. It proves each mapping copies the entity's own
 * fields with no service or repository call (architecture-spec §9): {@link #toResponse(OrderItem,
 * Long)} copies an order line's snapshot fields and sets the resolved {@code productId}; the
 * {@code toAdmin*} mappings (Sprint 12) additionally resolve the owning customer's account identity
 * by walking the order's existing {@code user} association, and never compute the aggregate
 * {@code itemCount} / {@code items} themselves — those are passed in exactly as the service supplies
 * them.
 */
class OrderMapperTest {

    private final OrderMapper mapper = new OrderMapperImpl();

    private User customer() {
        User user = new User();
        user.setId(42L);
        user.setFullName("Jane Doe");
        user.setEmail("jane@example.com");
        user.setPhone("0900000001");
        return user;
    }

    private Order order(User user) {
        Order order = new Order();
        order.setId(9L);
        order.setOrderCode("FV-ORDER-9");
        order.setUser(user);
        order.setStatus(OrderStatus.PENDING);
        order.setPaymentMethod(PaymentMethod.COD);
        order.setPaymentStatus(PaymentStatus.UNPAID);
        order.setSubtotal(new BigDecimal("200.00"));
        order.setDiscountAmount(BigDecimal.ZERO);
        order.setShippingFee(new BigDecimal("30000.00"));
        order.setTotal(new BigDecimal("30200.00"));
        order.setShippingRecipientName("Jane Doe");
        order.setShippingRecipientPhone("0912345678");
        order.setShippingProvince("HCM");
        order.setShippingDistrict("D1");
        order.setShippingWard("W1");
        order.setShippingStreetAddress("1 Street");
        return order;
    }

    /**
     * An order line maps to its response with the snapshot fields copied by name and the resolved
     * {@code productId} taken from the passed-in argument.
     */
    @Test
    void toResponseCopiesSnapshotFieldsAndSetsResolvedProductId() {
        OrderItem item = new OrderItem();
        item.setId(1L);
        item.setProductVariantId(7L);
        item.setProductName("Air Force 1");
        item.setProductImageUrl("img.png");
        item.setColor("Black");
        item.setSize("42");
        item.setUnitPrice(new BigDecimal("100.00"));
        item.setQuantity(2);
        item.setLineTotal(new BigDecimal("200.00"));

        OrderItemResponse response = mapper.toResponse(item, 100L);

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.productVariantId()).isEqualTo(7L);
        assertThat(response.productId()).isEqualTo(100L);
        assertThat(response.productName()).isEqualTo("Air Force 1");
        assertThat(response.productImageUrl()).isEqualTo("img.png");
        assertThat(response.color()).isEqualTo("Black");
        assertThat(response.size()).isEqualTo("42");
        assertThat(response.unitPrice()).isEqualByComparingTo("100.00");
        assertThat(response.quantity()).isEqualTo(2);
        assertThat(response.lineTotal()).isEqualByComparingTo("200.00");
    }

    /**
     * An order maps to its ADMIN summary response with the order's own fields copied, the owning
     * customer's account identity resolved from {@code order.user}, and the {@code itemCount}
     * exactly the value passed in — never computed by the mapper.
     */
    @Test
    void toAdminSummaryResponseCopiesOwnFieldsAndResolvesCustomerIdentity() {
        Order order = order(customer());

        AdminOrderSummaryResponse response = mapper.toAdminSummaryResponse(order, 3);

        assertThat(response.id()).isEqualTo(9L);
        assertThat(response.orderCode()).isEqualTo("FV-ORDER-9");
        assertThat(response.status()).isEqualTo(OrderStatus.PENDING);
        assertThat(response.paymentStatus()).isEqualTo(PaymentStatus.UNPAID);
        assertThat(response.total()).isEqualByComparingTo("30200.00");
        assertThat(response.itemCount()).isEqualTo(3);
        assertThat(response.customerId()).isEqualTo(42L);
        assertThat(response.customerFullName()).isEqualTo("Jane Doe");
        assertThat(response.customerEmail()).isEqualTo("jane@example.com");
        assertThat(response.customerPhone()).isEqualTo("0900000001");
    }

    /**
     * An order maps to its ADMIN detail response with the order's own fields (including the
     * shipping snapshot), the applied coupon's code, the owning customer's account identity, and the
     * {@code items} list exactly the value passed in — never assembled by the mapper.
     */
    @Test
    void toAdminDetailResponseCopiesOwnFieldsCouponCodeAndResolvesCustomerIdentity() {
        Order order = order(customer());
        Coupon coupon = new Coupon();
        coupon.setCode("SAVE10");
        order.setCoupon(coupon);
        OrderItemResponse item = new OrderItemResponse(1L, 7L, 100L, "Air Force 1", "img.png", "Black", "42",
                new BigDecimal("100.00"), 2, new BigDecimal("200.00"));

        AdminOrderDetailResponse response = mapper.toAdminDetailResponse(order, List.of(item));

        assertThat(response.id()).isEqualTo(9L);
        assertThat(response.orderCode()).isEqualTo("FV-ORDER-9");
        assertThat(response.couponCode()).isEqualTo("SAVE10");
        assertThat(response.shippingRecipientName()).isEqualTo("Jane Doe");
        assertThat(response.shippingProvince()).isEqualTo("HCM");
        assertThat(response.items()).containsExactly(item);
        assertThat(response.customerId()).isEqualTo(42L);
        assertThat(response.customerFullName()).isEqualTo("Jane Doe");
        assertThat(response.customerEmail()).isEqualTo("jane@example.com");
        assertThat(response.customerPhone()).isEqualTo("0900000001");
    }
}
