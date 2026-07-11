package com.footverse.order.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.footverse.order.entity.DiscountType;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

/**
 * Admin payload for {@code PUT /coupons/{id}} (validation-spec §12). Has the same field contract
 * as {@link CreateCouponRequest}; code uniqueness (against other coupons) and the {@code endAt}
 * after {@code startAt} window are business rules enforced by the service. {@code usedCount} is
 * never client-supplied — it is managed by checkout and cancellation.
 *
 * @param code              required, the unique coupon code (at most 64 characters)
 * @param name              required, the coupon name
 * @param description       optional, at most 2000 characters
 * @param discountType      required, the discount strategy
 * @param discountValue     required, strictly positive
 * @param minOrderAmount    required, zero or positive
 * @param maxDiscountAmount optional cap, strictly positive when present
 * @param startAt           required, the validity start
 * @param endAt             required, the validity end (must be after {@code startAt})
 * @param usageLimit        optional global usage cap, strictly positive when present
 * @param enabled           required enabled flag
 */
public record UpdateCouponRequest(
        @NotBlank @Size(max = 64) String code,
        @NotBlank String name,
        @Size(max = 2000) String description,
        @NotNull DiscountType discountType,
        @NotNull @Positive BigDecimal discountValue,
        @NotNull @PositiveOrZero BigDecimal minOrderAmount,
        @Positive BigDecimal maxDiscountAmount,
        @NotNull LocalDateTime startAt,
        @NotNull LocalDateTime endAt,
        @Positive Integer usageLimit,
        @NotNull Boolean enabled) {
}
