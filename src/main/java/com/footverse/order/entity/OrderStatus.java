package com.footverse.order.entity;

/**
 * Lifecycle status of an {@link Order} (dto-spec §4, database-spec §10.11). Persisted as a string
 * via {@code @Enumerated(EnumType.STRING)}.
 */
public enum OrderStatus {

    /** Placed, awaiting admin confirmation; the only status a customer may cancel. */
    PENDING,

    /** Confirmed by an admin. */
    CONFIRMED,

    /** Handed to shipping. */
    SHIPPING,

    /** Delivered to the customer; payment is marked paid at this point. */
    DELIVERED,

    /** Cancelled; stock and coupon usage are compensated. */
    CANCELLED
}
