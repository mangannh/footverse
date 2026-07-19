package com.footverse.order.dto;

/**
 * Result of the VNPay sandbox return callback ({@code GET /payments/vnpay/return}, dto-spec §15,
 * Sprint 13 Task 09).
 *
 * @param orderId      the order id the payment applies to
 * @param orderCode    the order's human-readable code
 * @param success      whether the payment was verified successful
 * @param responseCode the gateway's response code
 * @param message      user-safe result message
 */
public record VnpayReturnResponse(
        Long orderId, String orderCode, boolean success, String responseCode, String message) {
}
