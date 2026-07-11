package com.footverse.order.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentStatus;

/**
 * A compact order for the caller's order-history list (dto-spec §15). The {@code itemCount} is the
 * sum of the order's item quantities — an aggregate assembled by the service, not stored on the
 * order.
 *
 * @param id            the order id
 * @param orderCode     the immutable human-readable order code
 * @param status        the current order status
 * @param paymentStatus the current payment status
 * @param total         the snapshotted order total
 * @param itemCount     the sum of the order-item quantities
 * @param createdAt     the creation timestamp
 */
public record OrderSummaryResponse(
        Long id,
        String orderCode,
        OrderStatus status,
        PaymentStatus paymentStatus,
        BigDecimal total,
        int itemCount,
        LocalDateTime createdAt) {
}
