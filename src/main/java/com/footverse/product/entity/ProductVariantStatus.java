package com.footverse.product.entity;

/**
 * Lifecycle status of a {@link ProductVariant} (database-spec §10.8). Persisted as a string via
 * {@code @Enumerated(EnumType.STRING)}.
 */
public enum ProductVariantStatus {

    /** The variant is sellable (purchasability still also depends on stock). */
    ACTIVE,

    /** The variant is hidden from sale. */
    INACTIVE
}
