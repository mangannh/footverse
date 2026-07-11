package com.footverse.order.entity;

/**
 * Payment status of an {@link Order} (dto-spec §4, database-spec §10.11). Persisted as a string via
 * {@code @Enumerated(EnumType.STRING)}. An order starts {@code UNPAID} and becomes {@code PAID} when
 * delivered.
 */
public enum PaymentStatus {

    /** Not yet paid; the initial status of every order. */
    UNPAID,

    /** Paid; set when the order is delivered. */
    PAID
}
