package com.footverse.order;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.util.List;

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
import com.footverse.order.repository.OrderRepository;
import com.footverse.order.repository.PaymentTransactionRepository;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;

/**
 * {@code @DataJpaTest} for the {@code V6__create_payment_transaction.sql} migration
 * (testing-guidelines §Repository Testing, sprint-13-plan Task 08): the table exists with the
 * frozen columns/nullability (database-spec §10.17), {@code txn_ref} carries a unique key, and the
 * {@code ON DELETE CASCADE} foreign key to {@code orders} actually removes rows.
 *
 * <p>Runs against the real configured MySQL datasource (no embedded test database in this
 * project); {@link JpaAuditingConfig} is imported explicitly because {@code @DataJpaTest}'s slice
 * scan does not pick up plain {@code @Configuration} beans, and the seeded rows rely on
 * {@code @CreatedDate} being auto-populated. Mirrors {@code PasswordResetTokenMigrationTest}
 * (Sprint 13 Task 04) and {@code OrderItemCostSnapshotMigrationTest} (Sprint 12 Task 02).</p>
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig.class)
class PaymentTransactionMigrationTest {

    private static final String EMAIL = "payment-transaction-migration-test@example.com";
    private static final String PHONE = "0900000097";

    @Autowired
    private EntityManager entityManager;

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private PaymentTransactionRepository paymentTransactionRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * The {@code payment_transaction} table exists with the frozen columns and their nullability
     * (database-spec §10.17) — read directly from {@code information_schema}, independent of the
     * JPA entity mapping, so a stray annotation on the entity cannot mask a schema mismatch.
     */
    @Test
    void tableExistsWithFrozenColumnsAndNullability() {
        Query query = entityManager.createNativeQuery(
                "SELECT COLUMN_NAME, IS_NULLABLE FROM information_schema.COLUMNS "
                        + "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_transaction' "
                        + "ORDER BY ORDINAL_POSITION");

        @SuppressWarnings("unchecked")
        List<Object[]> rows = query.getResultList();

        assertThat(rows).extracting(row -> row[0])
                .containsExactly("id", "order_id", "txn_ref", "provider", "amount", "status",
                        "provider_txn_no", "response_code", "paid_at", "created_at", "updated_at");

        assertThat(nullability(rows, "order_id")).isEqualTo("NO");
        assertThat(nullability(rows, "txn_ref")).isEqualTo("NO");
        assertThat(nullability(rows, "provider")).isEqualTo("NO");
        assertThat(nullability(rows, "amount")).isEqualTo("NO");
        assertThat(nullability(rows, "status")).isEqualTo("NO");
        assertThat(nullability(rows, "provider_txn_no")).isEqualTo("YES");
        assertThat(nullability(rows, "response_code")).isEqualTo("YES");
        assertThat(nullability(rows, "paid_at")).isEqualTo("YES");
    }

    /**
     * {@code txn_ref} carries a unique key — a duplicate value is rejected by the database, not
     * merely by application code.
     */
    @Test
    void txnRefHasAUniqueKey() {
        Query query = entityManager.createNativeQuery(
                "SELECT COUNT(*) FROM information_schema.STATISTICS "
                        + "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payment_transaction' "
                        + "AND INDEX_NAME = 'uk_payment_transaction_txn_ref' "
                        + "AND NON_UNIQUE = 0");

        Number count = (Number) query.getSingleResult();

        assertThat(count.intValue()).isEqualTo(1);
    }

    /**
     * The {@code fk_payment_transaction_orders} foreign key is {@code ON DELETE CASCADE}: deleting
     * the owning order removes the transaction row with it, exactly like {@code order_item}.
     */
    @Test
    void deletingTheOwningOrderCascadesToTheTransactionRow() {
        User customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        Order order = orderRepository.save(order(customer));
        PaymentTransaction transaction = new PaymentTransaction();
        transaction.setOrder(order);
        transaction.setTxnRef("TXN-" + System.nanoTime());
        transaction.setProvider("VNPAY");
        transaction.setAmount(new BigDecimal("100.00"));
        transaction.setStatus(PaymentTransactionStatus.PENDING);
        PaymentTransaction saved = paymentTransactionRepository.saveAndFlush(transaction);
        Long orderId = order.getId();
        // Clear the persistence context so the delete below does not trip over the still-managed
        // `order`/`transaction` instances from the setup above (the
        // OrderItemCostSnapshotMigrationTest precedent).
        entityManager.clear();

        orderRepository.deleteById(orderId);
        orderRepository.flush();

        assertThat(paymentTransactionRepository.findById(saved.getId())).isEmpty();
    }

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

    private String nullability(List<Object[]> rows, String columnName) {
        return rows.stream()
                .filter(row -> row[0].equals(columnName))
                .map(row -> (String) row[1])
                .findFirst()
                .orElseThrow(() -> new AssertionError("column not found: " + columnName));
    }
}
