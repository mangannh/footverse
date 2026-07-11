package com.footverse.order.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.footverse.order.entity.DiscountType;

/**
 * A coupon returned to admins for management (dto-spec §14).
 *
 * @param id                the coupon id
 * @param code              the unique coupon code
 * @param name              the coupon name
 * @param description       the description, if any
 * @param discountType      the discount strategy ({@code PERCENT} / {@code FIXED})
 * @param discountValue     the discount value
 * @param minOrderAmount    the minimum order subtotal required
 * @param maxDiscountAmount the cap for percentage discounts, if any
 * @param startAt           the validity start
 * @param endAt             the validity end
 * @param usageLimit        the global usage cap ({@code null} = unlimited)
 * @param usedCount         the current usage count
 * @param enabled           whether the coupon is enabled
 */
public record CouponResponse(
        Long id,
        String code,
        String name,
        String description,
        DiscountType discountType,
        BigDecimal discountValue,
        BigDecimal minOrderAmount,
        BigDecimal maxDiscountAmount,
        LocalDateTime startAt,
        LocalDateTime endAt,
        Integer usageLimit,
        int usedCount,
        boolean enabled) {
}
