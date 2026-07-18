package com.footverse.order.repository;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import com.footverse.common.config.JpaAuditingConfig;
import com.footverse.order.entity.Order;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

/**
 * {@code @DataJpaTest} for {@link OrderRepository#searchForAdmin} (testing-guidelines §Repository
 * Testing, sprint-12-plan Task 01): the single JPQL query serving the ADMIN order search across all
 * four filter combinations (neither / status only / code only / both), the {@code orderCode}
 * contains-match, and pagination. Runs against the real configured MySQL datasource — this project
 * has no embedded test database — so {@link AutoConfigureTestDatabase.Replace#NONE} keeps Spring Boot
 * from trying to substitute one; each test method runs in its own transaction, rolled back
 * automatically by {@code @DataJpaTest}. {@link JpaAuditingConfig} is imported explicitly because
 * {@code @DataJpaTest}'s slice scan does not pick up plain {@code @Configuration} beans, and the
 * seeded orders rely on {@code @CreatedDate} (a {@code NOT NULL} column) being auto-populated.
 *
 * <p>The local development database is not guaranteed empty (other manual runs may have left rows
 * behind), so every seeded order code carries the {@link #TAG} prefix — a fragment unique enough that
 * no pre-existing row can ever match it. Assertions that must be exact (the contains-match, the
 * combined filter, pagination) scope their query through {@code TAG} so a dirty table cannot affect
 * them; the one assertion that queries with no filter at all uses a large page size and a
 * {@code contains} check rather than an exact count, so it stays correct however many unrelated rows
 * already exist.</p>
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig.class)
class OrderRepositoryTest {

    private static final String EMAIL = "order-repo-test@example.com";
    private static final String PHONE = "0900000097";
    private static final String TAG = "ORDERREPOTEST";

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private UserRepository userRepository;

    private User customer;

    @BeforeEach
    void seedOrders() {
        customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        orderRepository.save(order(TAG + "-AAA-1", OrderStatus.PENDING));
        orderRepository.save(order(TAG + "-AAA-2", OrderStatus.DELIVERED));
        orderRepository.save(order(TAG + "-BBB-1", OrderStatus.PENDING));
    }

    private Order order(String orderCode, OrderStatus status) {
        Order order = new Order();
        order.setOrderCode(orderCode);
        order.setUser(customer);
        order.setStatus(status);
        order.setPaymentMethod(PaymentMethod.COD);
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

    /**
     * With neither filter, the seeded orders are among the results — asserted by containment (not an
     * exact count) and a page large enough to hold every pre-existing row, so the assertion holds
     * regardless of what else is already in the shared local database.
     */
    @Test
    void searchForAdminWithNoFilterReturnsAllOrders() {
        Page<Order> page = orderRepository.searchForAdmin(null, null, PageRequest.of(0, 1000));

        assertThat(page.getContent()).extracting(Order::getOrderCode)
                .contains(TAG + "-AAA-1", TAG + "-AAA-2", TAG + "-BBB-1");
    }

    /**
     * With {@code status} only, every returned order is in that status — a universal invariant proven
     * without depending on the table being otherwise empty — and the seeded {@code DELIVERED} order is
     * among them.
     */
    @Test
    void searchForAdminWithStatusOnlyFiltersByStatus() {
        Page<Order> page = orderRepository.searchForAdmin(OrderStatus.DELIVERED, TAG, PageRequest.of(0, 20));

        assertThat(page.getContent()).allSatisfy(order -> assertThat(order.getStatus())
                .isEqualTo(OrderStatus.DELIVERED));
        assertThat(page.getContent()).extracting(Order::getOrderCode).containsExactly(TAG + "-AAA-2");
    }

    /**
     * With {@code orderCode} only, the match is a <strong>contains</strong> search — not a prefix or
     * an exact match — proven by a fragment that appears in the middle of two of the seeded codes. The
     * {@link #TAG} prefix makes the fragment unique enough that no pre-existing row can match it, so
     * the result is asserted exactly.
     */
    @Test
    void searchForAdminWithOrderCodeOnlyMatchesContains() {
        Page<Order> page = orderRepository.searchForAdmin(null, TAG + "-AAA", PageRequest.of(0, 20));

        assertThat(page.getContent()).extracting(Order::getOrderCode)
                .containsExactlyInAnyOrder(TAG + "-AAA-1", TAG + "-AAA-2");
    }

    /**
     * With both {@code status} and {@code orderCode} supplied, the two combine ({@code AND}) rather
     * than either alone deciding the result.
     */
    @Test
    void searchForAdminWithStatusAndOrderCodeCombinesBoth() {
        Page<Order> page = orderRepository.searchForAdmin(OrderStatus.PENDING, TAG + "-AAA", PageRequest.of(0, 20));

        assertThat(page.getContent()).extracting(Order::getOrderCode).containsExactly(TAG + "-AAA-1");
    }

    /**
     * A combination matching no seeded order returns an empty page, not an error.
     */
    @Test
    void searchForAdminWithNoMatchReturnsEmptyPage() {
        Page<Order> page = orderRepository.searchForAdmin(OrderStatus.DELIVERED, TAG + "-BBB", PageRequest.of(0, 20));

        assertThat(page.getContent()).isEmpty();
    }

    /**
     * The query honours pagination: scoped to just the three seeded orders (via the unique
     * {@link #TAG} fragment), a page size of one yields three total pages and one order per page.
     */
    @Test
    void searchForAdminHonoursPagination() {
        Pageable onePerPage = PageRequest.of(0, 1, Sort.by(Sort.Direction.ASC, "orderCode"));

        Page<Order> firstPage = orderRepository.searchForAdmin(null, TAG, onePerPage);

        assertThat(firstPage.getContent()).hasSize(1);
        assertThat(firstPage.getTotalElements()).isEqualTo(3);
        assertThat(firstPage.getTotalPages()).isEqualTo(3);
    }
}
