package com.footverse.order.entity;

/**
 * Discount computation strategy of a {@link Coupon} (database-spec §10.4, §14). Persisted as a
 * string via {@code @Enumerated(EnumType.STRING)}.
 */
public enum DiscountType {

    /** A percentage of the order subtotal, optionally capped by {@code max_discount_amount}. */
    PERCENT,

    /** A fixed money amount subtracted from the order subtotal. */
    FIXED
}
