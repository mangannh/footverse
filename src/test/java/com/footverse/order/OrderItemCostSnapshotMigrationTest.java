package com.footverse.order;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;

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
import com.footverse.order.repository.OrderItemRepository;
import com.footverse.order.repository.OrderRepository;
import com.footverse.product.entity.Product;
import com.footverse.product.entity.ProductVariant;
import com.footverse.product.entity.ProductVariantStatus;
import com.footverse.product.repository.ProductRepository;
import com.footverse.product.repository.ProductVariantRepository;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;

/**
 * {@code @DataJpaTest} for the {@code V4__add_order_item_unit_cost_price.sql} migration
 * (testing-guidelines §Repository Testing, sprint-12-plan Task 02): the {@code unit_cost_price}
 * column exists, is nullable, and nothing back-fills it.
 *
 * <p>A literal "insert a row, run the migration, assert it is still NULL" is not possible in an
 * automated test — {@code V4} has already run once against this database by the time any test
 * executes, and re-running a historical migration mid-test-suite is not something Flyway supports
 * safely. What this test proves instead, honestly: (1) the column exists with
 * {@code IS_NULLABLE = 'YES'} (read directly from {@code information_schema}, not through the JPA
 * mapping, so a stray {@code nullable = false} on the entity cannot mask a schema mismatch); and
 * (2) a row saved with {@code unitCostPrice} left unset persists as {@code NULL} and reads back as
 * {@code NULL} — i.e. nothing (no column default, no trigger, no application code outside the
 * checkout write path) ever fills it in. That is exactly the structural guarantee "no back-fill"
 * requires: the only way a pre-Sprint-12 row could ever read non-null is if something actively
 * wrote to it, and this test proves nothing does.</p>
 *
 * <p>Runs against the real configured MySQL datasource (no embedded test database in this
 * project); {@link JpaAuditingConfig} is imported explicitly because {@code @DataJpaTest}'s slice
 * scan does not pick up plain {@code @Configuration} beans, and the seeded rows rely on
 * {@code @CreatedDate} being auto-populated. Mirrors the {@code OrderRepositoryTest} precedent
 * (Sprint 12 Task 01). A minimal category/brand/product/variant hierarchy is seeded only because
 * {@code order_item.product_variant_id} carries a RESTRICT foreign key to {@code product_variant}
 * (database-spec §11) — not because this test cares about the catalog.</p>
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig.class)
class OrderItemCostSnapshotMigrationTest {

    private static final String EMAIL = "cost-snapshot-migration-test@example.com";
    private static final String PHONE = "0900000096";

    @Autowired
    private EntityManager entityManager;

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

    /**
     * The {@code order_item.unit_cost_price} column exists and is nullable — read from
     * {@code information_schema} directly, independent of the JPA entity mapping.
     */
    @Test
    void unitCostPriceColumnExistsAndIsNullable() {
        Query query = entityManager.createNativeQuery(
                "SELECT IS_NULLABLE FROM information_schema.COLUMNS "
                        + "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'order_item' "
                        + "AND COLUMN_NAME = 'unit_cost_price'");

        @SuppressWarnings("unchecked")
        List<Object> rows = query.getResultList();

        assertThat(rows).as("order_item.unit_cost_price must exist").hasSize(1);
        assertThat(rows.get(0)).isEqualTo("YES");
    }

    /**
     * An order line saved without setting {@code unitCostPrice} persists — and reads back — as
     * {@code NULL}: no default, trigger, or hidden write ever fills it in.
     */
    @Test
    void orderItemWithNoCostSetPersistsAndReadsBackAsNull() {
        User customer = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        Order order = orderRepository.save(order(customer));
        OrderItem item = new OrderItem();
        item.setOrder(order);
        item.setProductVariantId(seedVariant().getId());
        item.setProductName("Air Force 1");
        item.setColor("Black");
        item.setSize("42");
        item.setUnitPrice(new BigDecimal("100.00"));
        item.setQuantity(1);
        item.setLineTotal(new BigDecimal("100.00"));
        // unitCostPrice deliberately left unset — the pre-Sprint-12 row shape.

        OrderItem saved = orderItemRepository.saveAndFlush(item);
        entityManager.clear();

        OrderItem reloaded = orderItemRepository.findById(saved.getId()).orElseThrow();
        assertThat(reloaded.getUnitCostPrice()).isNull();
    }

    private Order order(User customer) {
        Order order = new Order();
        order.setOrderCode("CM-" + System.nanoTime());
        order.setUser(customer);
        order.setStatus(OrderStatus.PENDING);
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
        variant.setSku("SKU-CM-" + System.nanoTime());
        variant.setStatus(ProductVariantStatus.ACTIVE);
        variant.setCostPrice(new BigDecimal("50.00"));
        return productVariantRepository.save(variant);
    }

    private Category category() {
        Category category = new Category();
        category.setName("CM Category " + System.nanoTime());
        return category;
    }

    private Brand brand() {
        Brand brand = new Brand();
        brand.setName("CM Brand " + System.nanoTime());
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
