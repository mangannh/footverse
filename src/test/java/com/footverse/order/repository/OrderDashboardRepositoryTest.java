package com.footverse.order.repository;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageRequest;

import com.footverse.brand.entity.Brand;
import com.footverse.brand.repository.BrandRepository;
import com.footverse.category.entity.Category;
import com.footverse.category.repository.CategoryRepository;
import com.footverse.common.config.JpaAuditingConfig;
import com.footverse.order.entity.Order;
import com.footverse.order.entity.OrderItem;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;
import com.footverse.product.entity.Product;
import com.footverse.product.entity.ProductVariant;
import com.footverse.product.entity.ProductVariantStatus;
import com.footverse.product.repository.ProductRepository;
import com.footverse.product.repository.ProductVariantRepository;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import jakarta.persistence.EntityManager;

/**
 * {@code @DataJpaTest} for the five ADMIN dashboard aggregate reads on {@link OrderRepository}
 * (testing-guidelines §Repository Testing, sprint-13-plan Task 01): revenue, the per-status count,
 * the gross-profit summary (with the {@code unitCostPrice IS NULL} exclusion — Design Decision 2 —
 * being the single highest-value assertion in this file), the monthly revenue series, and the
 * per-variant best-seller aggregate. Runs against the real configured MySQL datasource (no embedded
 * test database in this project, mirroring {@code OrderRepositoryTest} / sprint-12-plan Task 01).
 *
 * <p>Every dashboard aggregate reads the <strong>entire</strong> {@code orders} / {@code order_item}
 * table — unlike {@code searchForAdmin}, it takes no filter a seeded row could be tagged with — so a
 * shared, non-empty local database cannot be worked around by scoping a query to a unique fragment.
 * Every assertion here is therefore a <strong>before/after delta</strong>: read the aggregate, seed
 * exactly the rows this test controls, read the aggregate again, and assert the difference matches
 * what was seeded — a universal invariant that holds regardless of whatever else is already in the
 * table. The one exception is the monthly-revenue cutoff, proven as an invariant over every returned
 * row rather than a delta (mirroring the {@code OrderRepositoryTest} status-only assertion).</p>
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig.class)
class OrderDashboardRepositoryTest {

    private static final String EMAIL = "dashboard-repo-test@example.com";
    private static final String PHONE = "0900000095";

    @Autowired
    private OrderRepository orderRepository;

    @Autowired
    private OrderItemRepository orderItemRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private BrandRepository brandRepository;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private ProductVariantRepository productVariantRepository;

    @Autowired
    private EntityManager entityManager;

    private User customer;

    private User customer() {
        if (customer == null) {
            customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        }
        return customer;
    }

    /**
     * {@code sumTotalForDeliveredOrders} increases by exactly the {@code total} of a newly seeded
     * {@code DELIVERED} order, and is unaffected by a {@code PENDING} order seeded alongside it.
     */
    @Test
    void sumTotalForDeliveredOrdersCountsOnlyDeliveredOrders() {
        BigDecimal before = orderRepository.sumTotalForDeliveredOrders();

        orderRepository.save(order(OrderStatus.PENDING, new BigDecimal("999999.00")));
        orderRepository.save(order(OrderStatus.DELIVERED, new BigDecimal("30100.00")));

        BigDecimal after = orderRepository.sumTotalForDeliveredOrders();

        assertThat(after.subtract(before)).isEqualByComparingTo("30100.00");
    }

    /**
     * {@code countOrdersGroupedByStatus} increases the {@code PENDING} row by exactly one when a
     * {@code PENDING} order is seeded — a universal per-status delta, provable regardless of whatever
     * else is already in the table.
     */
    @Test
    void countOrdersGroupedByStatusCountsEveryStatus() {
        long before = countFor(orderRepository.countOrdersGroupedByStatus(), OrderStatus.PENDING);

        orderRepository.save(order(OrderStatus.PENDING, new BigDecimal("30100.00")));

        long after = countFor(orderRepository.countOrdersGroupedByStatus(), OrderStatus.PENDING);

        assertThat(after).isEqualTo(before + 1);
    }

    /**
     * The single highest-value assertion in this file (Design Decision 2): seeding one
     * {@code DELIVERED} order with two lines — one carrying a known {@code unitCostPrice}, the other
     * left {@code null} (the pre-Sprint-12 row shape, {@code OrderItemCostSnapshotMigrationTest}
     * technique) — increases {@code grossProfit} by <strong>only</strong> the known-cost line's
     * margin, {@code linesWithCost} by exactly one, and {@code linesTotal} by exactly two. The
     * null-cost line contributes nothing to the profit sum and is never coerced to zero.
     */
    @Test
    void profitSummaryExcludesLinesWithNullUnitCostPrice() {
        OrderRepository.ProfitSummaryProjection before = orderRepository.findDeliveredOrderItemProfitSummary();

        ProductVariant variant = seedVariant();
        Order order = orderRepository.save(order(OrderStatus.DELIVERED, new BigDecimal("30300.00")));

        OrderItem withCost = new OrderItem();
        withCost.setOrder(order);
        withCost.setProductVariantId(variant.getId());
        withCost.setProductName("Air Force 1");
        withCost.setColor("Black");
        withCost.setSize("42");
        withCost.setUnitPrice(new BigDecimal("100.00"));
        withCost.setUnitCostPrice(new BigDecimal("60.00"));
        withCost.setQuantity(2);
        withCost.setLineTotal(new BigDecimal("200.00"));
        orderItemRepository.saveAndFlush(withCost);

        OrderItem withoutCost = new OrderItem();
        withoutCost.setOrder(order);
        withoutCost.setProductVariantId(variant.getId());
        withoutCost.setProductName("Air Force 1");
        withoutCost.setColor("Black");
        withoutCost.setSize("42");
        withoutCost.setUnitPrice(new BigDecimal("100.00"));
        // unitCostPrice deliberately left unset — the pre-Sprint-12 row shape.
        withoutCost.setQuantity(1);
        withoutCost.setLineTotal(new BigDecimal("100.00"));
        orderItemRepository.saveAndFlush(withoutCost);

        OrderRepository.ProfitSummaryProjection after = orderRepository.findDeliveredOrderItemProfitSummary();

        // (100.00 - 60.00) * 2 = 80.00 from the known-cost line only; the null-cost line adds 0.
        assertThat(after.getGrossProfit().subtract(before.getGrossProfit())).isEqualByComparingTo("80.00");
        assertThat(after.getLinesWithCost() - before.getLinesWithCost()).isEqualTo(1);
        assertThat(after.getLinesTotal() - before.getLinesTotal()).isEqualTo(2);
    }

    /**
     * {@code findMonthlyDeliveredRevenueSince} increases the current month's revenue by exactly the
     * {@code total} of a newly seeded {@code DELIVERED} order placed now, and every returned row's
     * year/month is no older than the supplied cutoff — a universal invariant proven without depending
     * on the table being otherwise empty.
     */
    @Test
    void findMonthlyDeliveredRevenueSinceCoversCurrentMonthAndHonoursCutoff() {
        YearMonth currentMonth = YearMonth.now();
        LocalDateTime cutoff = currentMonth.minusMonths(11).atDay(1).atStartOfDay();

        BigDecimal before = revenueFor(orderRepository.findMonthlyDeliveredRevenueSince(cutoff), currentMonth);

        orderRepository.save(order(OrderStatus.DELIVERED, new BigDecimal("30100.00")));

        List<OrderRepository.MonthlyRevenueProjection> rows = orderRepository.findMonthlyDeliveredRevenueSince(cutoff);
        BigDecimal after = revenueFor(rows, currentMonth);

        assertThat(after.subtract(before)).isEqualByComparingTo("30100.00");
        assertThat(rows).allSatisfy(row -> assertThat(YearMonth.of(row.getYear(), row.getMonth()))
                .isAfterOrEqualTo(currentMonth.minusMonths(11)));
    }

    /**
     * {@code findMonthlyDeliveredRevenueSince} excludes a {@code DELIVERED} order placed before the
     * cutoff — proven by moving a seeded order's {@code created_at} thirteen months into the past
     * (a native {@code UPDATE}, since {@code created_at} is JPA-auditing-managed and not settable
     * through the entity) and confirming the current month's revenue is unaffected by it.
     */
    @Test
    void findMonthlyDeliveredRevenueSinceExcludesOrdersBeforeCutoff() {
        YearMonth currentMonth = YearMonth.now();
        LocalDateTime cutoff = currentMonth.minusMonths(11).atDay(1).atStartOfDay();
        BigDecimal beforeCurrentMonth =
                revenueFor(orderRepository.findMonthlyDeliveredRevenueSince(cutoff), currentMonth);

        Order tooOld = orderRepository.saveAndFlush(order(OrderStatus.DELIVERED, new BigDecimal("30100.00")));
        LocalDateTime thirteenMonthsAgo = LocalDateTime.now().minusMonths(13);
        entityManager.createNativeQuery("UPDATE orders SET created_at = :ts WHERE id = :id")
                .setParameter("ts", thirteenMonthsAgo)
                .setParameter("id", tooOld.getId())
                .executeUpdate();
        entityManager.clear();

        BigDecimal afterCurrentMonth =
                revenueFor(orderRepository.findMonthlyDeliveredRevenueSince(cutoff), currentMonth);

        assertThat(afterCurrentMonth).isEqualByComparingTo(beforeCurrentMonth);
    }

    /**
     * {@code findTopSellingDeliveredVariants} reports the seeded variant's units sold and revenue,
     * aggregated over {@code DELIVERED} lines only, found by variant id among however many other
     * variants already have sales in the shared table.
     */
    @Test
    void findTopSellingDeliveredVariantsAggregatesByVariant() {
        ProductVariant variant = seedVariant();
        Order order = orderRepository.save(order(OrderStatus.DELIVERED, new BigDecimal("30500.00")));
        OrderItem item = new OrderItem();
        item.setOrder(order);
        item.setProductVariantId(variant.getId());
        item.setProductName("Air Force 1");
        item.setColor("Black");
        item.setSize("42");
        item.setUnitPrice(new BigDecimal("100.00"));
        item.setUnitCostPrice(new BigDecimal("60.00"));
        item.setQuantity(3);
        item.setLineTotal(new BigDecimal("300.00"));
        orderItemRepository.saveAndFlush(item);

        List<OrderRepository.VariantSalesProjection> rows =
                orderRepository.findTopSellingDeliveredVariants(PageRequest.of(0, 1000));

        OrderRepository.VariantSalesProjection row = rows.stream()
                .filter(r -> r.getProductVariantId().equals(variant.getId()))
                .findFirst()
                .orElseThrow(() -> new AssertionError("seeded variant not found in best-seller aggregate"));
        assertThat(row.getQuantitySold()).isEqualTo(3);
        assertThat(row.getRevenue()).isEqualByComparingTo("300.00");
    }

    private long countFor(List<OrderRepository.StatusCountProjection> rows, OrderStatus status) {
        return rows.stream()
                .filter(row -> row.getStatus() == status)
                .mapToLong(OrderRepository.StatusCountProjection::getCount)
                .findFirst()
                .orElse(0L);
    }

    private BigDecimal revenueFor(List<OrderRepository.MonthlyRevenueProjection> rows, YearMonth yearMonth) {
        return rows.stream()
                .filter(row -> row.getYear() == yearMonth.getYear() && row.getMonth() == yearMonth.getMonthValue())
                .map(OrderRepository.MonthlyRevenueProjection::getRevenue)
                .findFirst()
                .orElse(BigDecimal.ZERO);
    }

    private Order order(OrderStatus status, BigDecimal total) {
        Order order = new Order();
        order.setOrderCode("DASH-" + System.nanoTime());
        order.setUser(customer());
        order.setStatus(status);
        order.setPaymentMethod(PaymentMethod.COD);
        order.setPaymentStatus(PaymentStatus.UNPAID);
        order.setSubtotal(total);
        order.setDiscountAmount(BigDecimal.ZERO);
        order.setShippingFee(BigDecimal.ZERO);
        order.setTotal(total);
        order.setShippingRecipientName("Jane Doe");
        order.setShippingRecipientPhone(PHONE);
        order.setShippingProvince("HCM");
        order.setShippingDistrict("D1");
        order.setShippingWard("W1");
        order.setShippingStreetAddress("1 Street");
        return order;
    }

    /**
     * Seeds the minimal category/brand/product/variant hierarchy the {@code order_item} RESTRICT
     * foreign key requires — a real variant, not because this test exercises catalog behaviour.
     */
    private ProductVariant seedVariant() {
        Category category = categoryRepository.save(category());
        Brand brand = brandRepository.save(brand());
        Product product = productRepository.save(product(category, brand));

        ProductVariant variant = new ProductVariant();
        variant.setProduct(product);
        variant.setColor("Black");
        variant.setSize("42");
        variant.setStockQuantity(10);
        variant.setSku("SKU-DASH-" + System.nanoTime());
        variant.setStatus(ProductVariantStatus.ACTIVE);
        variant.setCostPrice(new BigDecimal("60.00"));
        return productVariantRepository.save(variant);
    }

    private Category category() {
        Category category = new Category();
        category.setName("Dashboard Category " + System.nanoTime());
        return category;
    }

    private Brand brand() {
        Brand brand = new Brand();
        brand.setName("Dashboard Brand " + System.nanoTime());
        return brand;
    }

    private Product product(Category category, Brand brand) {
        Product product = new Product();
        product.setName("Air Force 1");
        product.setBasePrice(new BigDecimal("100.00"));
        product.setCategory(category);
        product.setBrand(brand);
        return product;
    }
}
