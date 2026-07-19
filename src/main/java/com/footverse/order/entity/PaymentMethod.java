package com.footverse.order.entity;

/**
 * Payment method of an {@link Order} (dto-spec §4, database-spec §10.11). Persisted as a string via
 * {@code @Enumerated(EnumType.STRING)}. {@code VNPAY} is the sandbox-integrated online gateway added
 * in Sprint 13 (business-rules → Payment, Design Decision 5); no other gateway is added.
 */
public enum PaymentMethod {

    /** Cash on delivery — the original V1 method. */
    COD,

    /** VNPay sandbox — the one online gateway integrated in Sprint 13. */
    VNPAY
}
