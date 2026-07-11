package com.footverse.order.dto;

import java.util.List;

import org.hibernate.validator.constraints.UniqueElements;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * Request to preview the effect of an optional coupon on the caller's selected cart items
 * ({@code POST /coupons/validate}, dto-spec §14, validation-spec §9). Ownership of the cart items is
 * a business rule enforced by the service.
 *
 * @param code        optional coupon code; omit to preview the totals without a coupon
 * @param cartItemIds the selected cart item ids to price; required, non-empty, each positive and
 *                    unique (a duplicate id is rejected as {@code 400 VALIDATION_ERROR},
 *                    sprint-4-plan assumption 8)
 */
public record CouponPreviewRequest(
        @Size(max = 64) String code,
        @NotEmpty @UniqueElements List<@Positive Long> cartItemIds) {
}
