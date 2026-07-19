package com.footverse.order.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.footverse.common.entity.BaseEntity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import lombok.Getter;
import lombok.Setter;

/**
 * One payment-gateway attempt against an {@link Order} (database-spec §10.17, Sprint 13 Task 08).
 * Maps to the {@code payment_transaction} table; audit timestamps are inherited from
 * {@link BaseEntity}.
 *
 * <p>References its order through a lazy {@code @ManyToOne} on the {@code fk_payment_transaction_orders}
 * foreign key (CASCADE on order delete, mirroring {@link OrderItem}). One row per attempt: a new
 * attempt on the same order supersedes the previous {@link PaymentTransactionStatus#PENDING} row
 * (marked {@link PaymentTransactionStatus#FAILED}) rather than reusing it, keeping a complete,
 * auditable attempt history. {@link #status} is independent of {@link Order#getPaymentStatus()} — the
 * order's payment status flips to {@code PAID} exactly once, on a verified
 * {@link PaymentTransactionStatus#SUCCESS} (Design Decision 7).</p>
 */
@Getter
@Setter
@Entity
@Table(name = "payment_transaction")
public class PaymentTransaction extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "txn_ref", nullable = false, unique = true, length = 64)
    private String txnRef;

    @Column(nullable = false, length = 20)
    private String provider;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentTransactionStatus status;

    @Column(name = "provider_txn_no", length = 64)
    private String providerTxnNo;

    @Column(name = "response_code", length = 20)
    private String responseCode;

    @Column(name = "paid_at")
    private LocalDateTime paidAt;
}
