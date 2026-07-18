package com.footverse.order.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;

/**
 * The full detail of an order for ADMIN management (dto-spec §15, Sprint 12). Mirrors
 * {@link OrderDetailResponse} field-for-field — including the shipping snapshot, which already
 * carries the delivery address, so no separate {@code customerAddress} field is added — plus the
 * owning customer's account identity, which the customer-scoped DTO deliberately omits. {@code items}
 * reuses the unchanged {@link OrderItemResponse}: order lines carry nothing that needs isolating from
 * ADMIN. The {@code items} list is an aggregate assembled by the service from the order's lines.
 *
 * @param id                     the order id
 * @param orderCode              the immutable order code
 * @param status                 the current order status
 * @param paymentMethod          the payment method ({@code COD})
 * @param paymentStatus          the current payment status
 * @param subtotal               the snapshotted subtotal
 * @param discountAmount         the snapshotted discount (0 when no coupon)
 * @param shippingFee            the snapshotted shipping fee
 * @param total                  the snapshotted total
 * @param couponCode             the applied coupon code, if any
 * @param shippingRecipientName  the shipping recipient name snapshot (the delivery address)
 * @param shippingRecipientPhone the shipping recipient phone snapshot (the delivery address)
 * @param shippingProvince       the shipping province snapshot (the delivery address)
 * @param shippingDistrict       the shipping district snapshot (the delivery address)
 * @param shippingWard           the shipping ward snapshot (the delivery address)
 * @param shippingStreetAddress  the shipping street address snapshot (the delivery address)
 * @param note                   the customer note, if any
 * @param items                  the order lines
 * @param createdAt              the creation timestamp
 * @param cancelledAt            the cancellation timestamp, if cancelled
 * @param deliveredAt            the delivery timestamp, if delivered
 * @param customerId             the owning customer's user id
 * @param customerFullName       the owning customer's full name
 * @param customerEmail          the owning customer's email
 * @param customerPhone          the owning customer's phone
 */
public record AdminOrderDetailResponse(
        Long id,
        String orderCode,
        OrderStatus status,
        PaymentMethod paymentMethod,
        PaymentStatus paymentStatus,
        BigDecimal subtotal,
        BigDecimal discountAmount,
        BigDecimal shippingFee,
        BigDecimal total,
        String couponCode,
        String shippingRecipientName,
        String shippingRecipientPhone,
        String shippingProvince,
        String shippingDistrict,
        String shippingWard,
        String shippingStreetAddress,
        String note,
        List<OrderItemResponse> items,
        LocalDateTime createdAt,
        LocalDateTime cancelledAt,
        LocalDateTime deliveredAt,
        Long customerId,
        String customerFullName,
        String customerEmail,
        String customerPhone) {
}
