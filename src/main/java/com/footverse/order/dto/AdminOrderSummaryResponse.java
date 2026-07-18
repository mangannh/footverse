package com.footverse.order.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentStatus;

/**
 * A compact order for the ADMIN order-management list (dto-spec §15, Sprint 12). A dedicated DTO —
 * never the customer {@link OrderSummaryResponse} — because it additionally carries the owning
 * customer's account identity, which the customer-scoped DTO deliberately omits (a caller answering
 * "my orders" already knows who they are). The {@code itemCount} is the sum of the order's item
 * quantities, assembled by the service, exactly as {@link OrderSummaryResponse#itemCount()}.
 *
 * @param id               the order id
 * @param orderCode        the immutable human-readable order code
 * @param status           the current order status
 * @param paymentStatus    the current payment status
 * @param total            the snapshotted order total
 * @param itemCount        the sum of the order-item quantities
 * @param createdAt        the creation timestamp
 * @param customerId       the owning customer's user id
 * @param customerFullName the owning customer's full name
 * @param customerEmail    the owning customer's email
 * @param customerPhone    the owning customer's phone
 */
public record AdminOrderSummaryResponse(
        Long id,
        String orderCode,
        OrderStatus status,
        PaymentStatus paymentStatus,
        BigDecimal total,
        int itemCount,
        LocalDateTime createdAt,
        Long customerId,
        String customerFullName,
        String customerEmail,
        String customerPhone) {
}
