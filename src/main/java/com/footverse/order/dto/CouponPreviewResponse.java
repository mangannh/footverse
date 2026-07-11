package com.footverse.order.dto;

import java.math.BigDecimal;

/**
 * The full server-computed checkout summary for the previewed items (dto-spec §14). Every amount is
 * computed by the server; the client never computes discounts or totals. The {@code code} / {@code
 * name} are present only when a valid coupon was supplied.
 *
 * @param code           the applied coupon code, if a valid coupon was supplied
 * @param name           the applied coupon name, if a valid coupon was supplied
 * @param subtotal       the sum of the selected line totals
 * @param discountAmount the computed discount (0 when no coupon)
 * @param shippingFee    the flat shipping fee
 * @param total          {@code subtotal − discountAmount + shippingFee}
 */
public record CouponPreviewResponse(
        String code,
        String name,
        BigDecimal subtotal,
        BigDecimal discountAmount,
        BigDecimal shippingFee,
        BigDecimal total) {
}
