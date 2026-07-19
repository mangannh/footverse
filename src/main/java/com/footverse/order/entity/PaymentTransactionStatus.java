package com.footverse.order.entity;

/**
 * Status of a single {@link PaymentTransaction} attempt (database-spec §10.17, Sprint 13 Task 08,
 * Design Decision 7). Persisted as a string via {@code @Enumerated(EnumType.STRING)}. Independent of
 * {@link PaymentStatus}: the order's payment status flips to {@code PAID} exactly once, on a verified
 * {@code SUCCESS} transaction; a {@code PENDING} or {@code FAILED} transaction never changes it.
 */
public enum PaymentTransactionStatus {

    /** A payment URL was issued and no verified outcome has been recorded yet. */
    PENDING,

    /** The gateway's return was verified and the payment succeeded. */
    SUCCESS,

    /** The transaction was superseded by a retry, or the order was cancelled while pending. */
    FAILED
}
