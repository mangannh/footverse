package com.footverse.order.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.order.entity.PaymentTransaction;
import com.footverse.order.entity.PaymentTransactionStatus;

/**
 * Data access for {@link PaymentTransaction} (Sprint 13 Task 08). Standard CRUD is inherited from
 * {@link JpaRepository}; the two reads below let {@code OrderService} resolve a transaction by the
 * gateway's {@code vnp_TxnRef} and find an order's current attempt.
 */
public interface PaymentTransactionRepository extends JpaRepository<PaymentTransaction, Long> {

    /**
     * Returns the transaction with the given gateway reference, as looked up by the VNPay return
     * callback.
     *
     * @param txnRef the unique transaction reference
     * @return the matching transaction, if any
     */
    Optional<PaymentTransaction> findByTxnRef(String txnRef);

    /**
     * Returns an order's most recent transaction in the given status, if any — used to find the
     * current {@link PaymentTransactionStatus#PENDING} attempt to supersede on a retry or a
     * cancellation.
     *
     * @param orderId the owning order id
     * @param status  the status to match
     * @return the most recently created matching transaction, if any
     */
    Optional<PaymentTransaction> findFirstByOrderIdAndStatusOrderByIdDesc(Long orderId, PaymentTransactionStatus status);
}
