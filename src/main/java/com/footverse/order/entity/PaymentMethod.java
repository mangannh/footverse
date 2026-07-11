package com.footverse.order.entity;

/**
 * Payment method of an {@link Order} (dto-spec §4, database-spec §10.11). Persisted as a string via
 * {@code @Enumerated(EnumType.STRING)}. V1 supports cash on delivery only.
 */
public enum PaymentMethod {

    /** Cash on delivery — the only method in V1. */
    COD
}
