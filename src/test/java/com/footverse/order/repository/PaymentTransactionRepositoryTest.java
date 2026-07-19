package com.footverse.order.repository;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;

import com.footverse.common.config.JpaAuditingConfig;
import com.footverse.order.entity.Order;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;
import com.footverse.order.entity.PaymentTransaction;
import com.footverse.order.entity.PaymentTransactionStatus;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import jakarta.persistence.EntityManager;

/**
 * {@code @DataJpaTest} for {@link PaymentTransactionRepository} (testing-guidelines §Repository
 * Testing, sprint-13-plan Task 08): lookup by the gateway's {@code txn_ref}, lookup of an order's
 * most recent transaction in a given status, and the {@code ON DELETE CASCADE} behaviour observed
 * through ordinary repository calls (the {@code PaymentTransactionMigrationTest} proves the same
 * cascade at the schema level). Runs against the real configured MySQL datasource (no embedded test
 * database in this project). {@link JpaAuditingConfig} is imported explicitly because
 * {@code @DataJpaTest}'s slice scan does not pick up plain {@code @Configuration} beans, and the
 * seeded rows rely on {@code @CreatedDate} being auto-populated.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig.class)
class PaymentTransactionRepositoryTest {

    private static final String EMAIL = "payment-transaction-repo-test@example.com";
    private static final String PHONE = "0900000098";

    @Autowired
    private PaymentTransactionRepository paymentTransactionRepository;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EntityManager entityManager;

    private Order order(User customer) {
        Order order = new Order();
        order.setOrderCode("PT-" + System.nanoTime());
        order.setUser(customer);
        order.setStatus(OrderStatus.PENDING);
        order.setPaymentMethod(PaymentMethod.VNPAY);
        order.setPaymentStatus(PaymentStatus.UNPAID);
        order.setSubtotal(new BigDecimal("100.00"));
        order.setDiscountAmount(BigDecimal.ZERO);
        order.setShippingFee(new BigDecimal("30000.00"));
        order.setTotal(new BigDecimal("30100.00"));
        order.setShippingRecipientName("Jane Doe");
        order.setShippingRecipientPhone(PHONE);
        order.setShippingProvince("HCM");
        order.setShippingDistrict("D1");
        order.setShippingWard("W1");
        order.setShippingStreetAddress("1 Street");
        return order;
    }

    private PaymentTransaction transaction(
            Order order, String txnRef, PaymentTransactionStatus status) {
        PaymentTransaction transaction = new PaymentTransaction();
        transaction.setOrder(order);
        transaction.setTxnRef(txnRef);
        transaction.setProvider("VNPAY");
        transaction.setAmount(order.getTotal());
        transaction.setStatus(status);
        return transaction;
    }

    /**
     * {@code findByTxnRef} returns the transaction with that gateway reference — the lookup the
     * VNPay return callback uses.
     */
    @Test
    void findByTxnRefReturnsTheMatchingTransaction() {
        User customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        Order order = orderRepository.save(order(customer));
        PaymentTransaction saved = paymentTransactionRepository.save(
                transaction(order, "TXN-FIND", PaymentTransactionStatus.PENDING));

        Optional<PaymentTransaction> found = paymentTransactionRepository.findByTxnRef("TXN-FIND");

        assertThat(found).isPresent();
        assertThat(found.orElseThrow().getId()).isEqualTo(saved.getId());
    }

    /**
     * {@code findByTxnRef} returns empty for an unknown reference.
     */
    @Test
    void findByTxnRefReturnsEmptyForAnUnknownReference() {
        assertThat(paymentTransactionRepository.findByTxnRef("TXN-UNKNOWN")).isEmpty();
    }

    /**
     * {@code findFirstByOrderIdAndStatusOrderByIdDesc} returns the most recently created
     * transaction in the given status — the row a retry supersedes.
     */
    @Test
    void findFirstByOrderIdAndStatusOrderByIdDescReturnsTheLatestMatch() {
        User customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        Order order = orderRepository.save(order(customer));
        paymentTransactionRepository.save(
                transaction(order, "TXN-OLD", PaymentTransactionStatus.FAILED));
        PaymentTransaction latestPending = paymentTransactionRepository.save(
                transaction(order, "TXN-NEW", PaymentTransactionStatus.PENDING));

        Optional<PaymentTransaction> found = paymentTransactionRepository
                .findFirstByOrderIdAndStatusOrderByIdDesc(order.getId(), PaymentTransactionStatus.PENDING);

        assertThat(found).isPresent();
        assertThat(found.orElseThrow().getId()).isEqualTo(latestPending.getId());
    }

    /**
     * {@code findFirstByOrderIdAndStatusOrderByIdDesc} returns empty when the order has no
     * transaction in that status.
     */
    @Test
    void findFirstByOrderIdAndStatusOrderByIdDescReturnsEmptyWhenNoneMatch() {
        User customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        Order order = orderRepository.save(order(customer));

        Optional<PaymentTransaction> found = paymentTransactionRepository
                .findFirstByOrderIdAndStatusOrderByIdDesc(order.getId(), PaymentTransactionStatus.SUCCESS);

        assertThat(found).isEmpty();
    }

    /**
     * Deleting the owning order cascades to the transaction row — observed here through ordinary
     * repository calls (the migration test proves the same at the schema/FK level).
     */
    @Test
    void deletingTheOwningOrderCascadesToTheTransactionRow() {
        User customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        Order order = orderRepository.save(order(customer));
        PaymentTransaction saved = paymentTransactionRepository.saveAndFlush(
                transaction(order, "TXN-CASCADE", PaymentTransactionStatus.PENDING));
        Long orderId = order.getId();
        entityManager.clear();

        orderRepository.deleteById(orderId);
        orderRepository.flush();

        assertThat(paymentTransactionRepository.findById(saved.getId())).isEmpty();
    }
}
