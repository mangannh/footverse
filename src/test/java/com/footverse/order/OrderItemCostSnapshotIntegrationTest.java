package com.footverse.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.common.security.JwtUtil;
import com.footverse.order.entity.OrderItem;
import com.footverse.order.repository.OrderItemRepository;
import com.footverse.support.AuthFixtures;
import com.footverse.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

import jakarta.persistence.EntityManager;

/**
 * End-to-end proof of the order-item cost snapshot (sprint-12-plan Task 02), through the real
 * filter chain, services, and database (no mocks): an ADMIN seeds a variant with a known
 * {@code costPrice}, a CUSTOMER checks out, and the persisted {@code order_item.unit_cost_price}
 * equals the variant's cost <strong>at that moment</strong> — read directly through
 * {@link OrderItemRepository}, since no DTO exposes it (Assumption 3, Design Decision 2). The ADMIN
 * then changes the variant's {@code costPrice} via {@code PUT /products/{id}/variants/{variantId}},
 * and the already-persisted order line is re-read and asserted <strong>unchanged</strong> — the
 * snapshot is immutable, exactly like {@code unitPrice}, {@code color}, and {@code size}
 * (database-spec §12).
 *
 * <p>Runs in a rolled-back transaction so no state leaks (the {@code CheckoutFlowIntegrationTest}
 * precedent).</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class OrderItemCostSnapshotIntegrationTest {

    private static final String ADMIN_EMAIL = "cost-snapshot-admin@example.com";
    private static final String ADMIN_PHONE = "0900000083";
    private static final String CUSTOMER_EMAIL = "cost-snapshot-customer@example.com";
    private static final String CUSTOMER_PHONE = "0900000084";

    private static final BigDecimal COST_AT_CHECKOUT = new BigDecimal("50.00");
    private static final BigDecimal COST_AFTER_EDIT = new BigDecimal("75.00");

    private static final String ADDRESS_BODY = """
            {"recipientName":"Jane Doe","recipientPhone":"0912345678","province":"HCM",
             "district":"D1","ward":"W1","streetAddress":"1 Nguyen Hue"}
            """;

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final OrderItemRepository orderItemRepository;
    private final EntityManager entityManager;

    OrderItemCostSnapshotIntegrationTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil,
            @Autowired UserRepository userRepository, @Autowired OrderItemRepository orderItemRepository,
            @Autowired EntityManager entityManager) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
        this.orderItemRepository = orderItemRepository;
        this.entityManager = entityManager;
    }

    @BeforeEach
    void persistUsers() {
        userRepository.save(AuthFixtures.admin(ADMIN_EMAIL, ADMIN_PHONE));
        userRepository.save(AuthFixtures.customer(CUSTOMER_EMAIL, CUSTOMER_PHONE));
    }

    private String adminToken() {
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private String customerToken() {
        return "Bearer " + jwtUtil.createAccessToken(CUSTOMER_EMAIL);
    }

    /** Performs an authenticated {@code POST} that must answer {@code 201 Created} and yields the created resource's id. */
    private long create(String path, String token, String json) throws Exception {
        String body = mockMvc.perform(post(path)
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.data.id")).longValue();
    }

    /**
     * The full write-then-verify-then-edit-then-reverify walk: checkout snapshots the variant's
     * cost at that moment; a later {@code costPrice} edit never touches the already-persisted line.
     */
    @Test
    void placeOrderSnapshotsCostThenLaterVariantCostEditLeavesItUnchanged() throws Exception {
        // 1. ADMIN seeds a purchasable variant with a known costPrice.
        long categoryId = create("/api/v1/categories", adminToken(), "{\"name\":\"CS Sneakers\"}");
        long brandId = create("/api/v1/brands", adminToken(), "{\"name\":\"CS Nike\"}");
        long productId = create("/api/v1/products", adminToken(),
                "{\"name\":\"CS Air Force 1\",\"description\":\"flow product\",\"basePrice\":100.00,"
                        + "\"categoryId\":" + categoryId + ",\"brandId\":" + brandId + "}");
        long variantId = create("/api/v1/products/" + productId + "/variants", adminToken(),
                "{\"color\":\"Black\",\"size\":\"42\",\"sku\":\"SKU-CS-42\",\"stockQuantity\":10,"
                        + "\"status\":\"ACTIVE\",\"costPrice\":" + COST_AT_CHECKOUT + "}");
        create("/api/v1/products/" + productId + "/images", adminToken(),
                "{\"imageUrl\":\"img.png\",\"displayOrder\":0,\"isPrimary\":true}");

        // 2. CUSTOMER checks out that variant.
        mockMvc.perform(post("/api/v1/cart/items")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productVariantId\":" + variantId + ",\"quantity\":1}"))
                .andExpect(status().isOk());
        String cartBody = mockMvc.perform(get("/api/v1/cart").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        List<Object> ids = JsonPath.read(cartBody,
                "$.data.items[?(@.productVariantId == " + variantId + ")].id");
        long cartItemId = ((Number) ids.get(0)).longValue();
        long addressId = create("/api/v1/addresses", customerToken(), ADDRESS_BODY);
        long orderId = create("/api/v1/orders", customerToken(),
                "{\"cartItemIds\":[" + cartItemId + "],\"addressId\":" + addressId + "}");

        // 3. The persisted order_item.unit_cost_price equals the variant's costPrice at checkout —
        // read through the repository directly, since no DTO exposes it.
        OrderItem itemAtCheckout = onlyLineOf(orderId);
        assertThat(itemAtCheckout.getUnitCostPrice()).isEqualByComparingTo(COST_AT_CHECKOUT);

        // 4. ADMIN edits the variant's costPrice afterwards.
        mockMvc.perform(put("/api/v1/products/" + productId + "/variants/" + variantId)
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"color\":\"Black\",\"size\":\"42\",\"sku\":\"SKU-CS-42\","
                                + "\"stockQuantity\":10,\"status\":\"ACTIVE\",\"costPrice\":" + COST_AFTER_EDIT + "}"))
                .andExpect(status().isOk());

        // 5. The already-placed order line is unaffected: it still reads the cost as of checkout,
        // never the variant's new cost — the snapshot is immutable. The persistence context is
        // cleared first so this re-read hits the database, not a cached first-level entity.
        entityManager.clear();
        OrderItem itemAfterEdit = onlyLineOf(orderId);
        assertThat(itemAfterEdit.getUnitCostPrice()).isEqualByComparingTo(COST_AT_CHECKOUT);
        assertThat(itemAfterEdit.getUnitCostPrice()).isNotEqualByComparingTo(COST_AFTER_EDIT);
    }

    private OrderItem onlyLineOf(long orderId) {
        List<OrderItem> lines = orderItemRepository.findByOrderId(orderId);
        assertThat(lines).hasSize(1);
        return lines.get(0);
    }
}
