package com.footverse.order.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;

/**
 * The full detail of an order with its checkout snapshots (dto-spec §15). Money and shipping fields
 * are frozen at checkout and returned exactly as persisted. The {@code items} list is an aggregate
 * assembled by the service from the order's lines.
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
 * @param shippingRecipientName  the shipping recipient name snapshot
 * @param shippingRecipientPhone the shipping recipient phone snapshot
 * @param shippingProvince       the shipping province snapshot
 * @param shippingDistrict       the shipping district snapshot
 * @param shippingWard           the shipping ward snapshot
 * @param shippingStreetAddress  the shipping street address snapshot
 * @param note                   the customer note, if any
 * @param items                  the order lines
 * @param createdAt              the creation timestamp
 * @param cancelledAt            the cancellation timestamp, if cancelled
 * @param deliveredAt            the delivery timestamp, if delivered
 */
public record OrderDetailResponse(
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
        LocalDateTime deliveredAt) {
}
