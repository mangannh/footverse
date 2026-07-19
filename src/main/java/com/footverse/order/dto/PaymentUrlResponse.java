package com.footverse.order.dto;

import java.time.LocalDateTime;

/**
 * The signed VNPay sandbox payment URL for a {@code VNPAY} order ({@code POST /orders/{id}/payment},
 * dto-spec §15, Sprint 13 Task 09).
 *
 * @param paymentUrl the signed VNPay sandbox payment URL
 * @param txnRef     the unique transaction reference the return callback resolves
 * @param expiresAt  when the payment URL expires
 */
public record PaymentUrlResponse(String paymentUrl, String txnRef, LocalDateTime expiresAt) {
}
