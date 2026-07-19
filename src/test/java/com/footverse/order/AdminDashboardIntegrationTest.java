package com.footverse.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

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
import com.footverse.support.AuthFixtures;
import com.footverse.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

/**
 * End-to-end proof of the ADMIN dashboard (sprint-13-plan Task 01), through the real filter chain,
 * services, and database (no mocks). The dashboard reads the <strong>entire</strong> {@code orders} /
 * {@code order_item} table — unlike the ADMIN order search, it accepts no filter a seeded row could
 * be tagged with — so this test proves the endpoint the same way {@code OrderDashboardRepositoryTest}
 * proves the underlying aggregates: a <strong>before/after delta</strong> around one order walked all
 * the way to {@code DELIVERED} through the real status machine, which is unaffected by whatever else
 * is already in the shared local database.
 *
 * <p>Runs in a rolled-back transaction so no state leaks (the {@code AdminOrderReadIntegrationTest}
 * precedent, sprint-12-plan Task 01).</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class AdminDashboardIntegrationTest {

    private static final String ADMIN_EMAIL = "dashboard-admin-it@example.com";
    private static final String ADMIN_PHONE = "0900000090";
    private static final String OWNER_EMAIL = "dashboard-owner-it@example.com";
    private static final String OWNER_PHONE = "0900000091";

    private static final String ADDRESS_BODY = """
            {"recipientName":"Jane Doe","recipientPhone":"0912345678","province":"HCM",
             "district":"D1","ward":"W1","streetAddress":"1 Nguyen Hue"}
            """;

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    AdminDashboardIntegrationTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil,
            @Autowired UserRepository userRepository) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    @BeforeEach
    void persistUsers() {
        userRepository.save(AuthFixtures.admin(ADMIN_EMAIL, ADMIN_PHONE));
        userRepository.save(AuthFixtures.customer(OWNER_EMAIL, OWNER_PHONE));
    }

    private String adminToken() {
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private String ownerToken() {
        return "Bearer " + jwtUtil.createAccessToken(OWNER_EMAIL);
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
     * Seeds a minimal ACTIVE, in-stock variant end-to-end (category, brand, product, variant, image)
     * with a known unit price (100.00) and cost price (50.00), mirroring the
     * {@code AdminOrderReadIntegrationTest} seeding shape, so the resulting order's revenue and
     * profit contribution are known exactly.
     */
    private long seedPurchasableVariant() throws Exception {
        long categoryId = create("/api/v1/categories", adminToken(), "{\"name\":\"Sneakers-DASH\"}");
        long brandId = create("/api/v1/brands", adminToken(), "{\"name\":\"Nike-DASH\"}");
        long productId = create("/api/v1/products", adminToken(),
                "{\"name\":\"Air Force 1 DASH\",\"description\":\"Classic\",\"basePrice\":100.00,"
                        + "\"categoryId\":" + categoryId + ",\"brandId\":" + brandId + "}");
        long variantId = create("/api/v1/products/" + productId + "/variants", adminToken(),
                "{\"color\":\"Black\",\"size\":\"42\",\"sku\":\"SKU-DASH-42\",\"stockQuantity\":10,"
                        + "\"status\":\"ACTIVE\",\"costPrice\":50.00}");
        create("/api/v1/products/" + productId + "/images", adminToken(),
                "{\"imageUrl\":\"img.png\",\"displayOrder\":1,\"isPrimary\":true}");
        return variantId;
    }

    /** Places one order for the owner customer (quantity 1) and returns its id. */
    private long placeOwnerOrder(long variantId) throws Exception {
        mockMvc.perform(post("/api/v1/cart/items")
                        .header(HttpHeaders.AUTHORIZATION, ownerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productVariantId\":" + variantId + ",\"quantity\":1}"))
                .andExpect(status().isOk());
        String cartBody = mockMvc.perform(get("/api/v1/cart").header(HttpHeaders.AUTHORIZATION, ownerToken()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        List<Object> ids = JsonPath.read(cartBody,
                "$.data.items[?(@.productVariantId == " + variantId + ")].id");
        long cartItemId = ((Number) ids.get(0)).longValue();
        long addressId = create("/api/v1/addresses", ownerToken(), ADDRESS_BODY);
        return create("/api/v1/orders", ownerToken(),
                "{\"cartItemIds\":[" + cartItemId + "],\"addressId\":" + addressId + "}");
    }

    /** Walks an order through the frozen forward machine to {@code DELIVERED} as the ADMIN. */
    private void advanceToDelivered(long orderId) throws Exception {
        for (String targetStatus : List.of("CONFIRMED", "SHIPPING", "DELIVERED")) {
            mockMvc.perform(patch("/api/v1/orders/" + orderId + "/status")
                            .header(HttpHeaders.AUTHORIZATION, adminToken())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"status\":\"" + targetStatus + "\"}"))
                    .andExpect(status().isOk());
        }
    }

    private String dashboardBody() throws Exception {
        return mockMvc.perform(get("/api/v1/admin/dashboard").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
    }

    /**
     * The core dashboard proof: an order walked to {@code DELIVERED} (total 30100.00, one line at
     * unit price 100.00 against a cost price of 50.00) increases {@code totalRevenue} by exactly its
     * total, {@code totalOrders} by exactly one, the {@code DELIVERED} row of {@code ordersByStatus}
     * by exactly one, and {@code grossProfit} by exactly the line's margin (50.00) with both coverage
     * counts up by one — proven as a delta so it holds regardless of whatever else is already in the
     * shared local database.
     */
    @Test
    void deliveredOrderIncreasesRevenueProfitAndStatusCountByExactlyItsOwnContribution() throws Exception {
        String before = dashboardBody();
        BigDecimal revenueBefore = new BigDecimal(JsonPath.read(before, "$.data.totalRevenue").toString());
        BigDecimal profitBefore = new BigDecimal(JsonPath.read(before, "$.data.grossProfit").toString());
        int ordersBefore = ((Number) JsonPath.read(before, "$.data.totalOrders")).intValue();
        long deliveredBefore = deliveredCount(before);
        long linesWithCostBefore = ((Number) JsonPath.read(before, "$.data.profitLinesWithCost")).longValue();
        long linesTotalBefore = ((Number) JsonPath.read(before, "$.data.profitLinesTotal")).longValue();

        long variantId = seedPurchasableVariant();
        long orderId = placeOwnerOrder(variantId);
        advanceToDelivered(orderId);

        String after = dashboardBody();
        BigDecimal revenueAfter = new BigDecimal(JsonPath.read(after, "$.data.totalRevenue").toString());
        BigDecimal profitAfter = new BigDecimal(JsonPath.read(after, "$.data.grossProfit").toString());
        int ordersAfter = ((Number) JsonPath.read(after, "$.data.totalOrders")).intValue();
        long deliveredAfter = deliveredCount(after);
        long linesWithCostAfter = ((Number) JsonPath.read(after, "$.data.profitLinesWithCost")).longValue();
        long linesTotalAfter = ((Number) JsonPath.read(after, "$.data.profitLinesTotal")).longValue();

        assertThat(revenueAfter.subtract(revenueBefore)).isEqualByComparingTo("30100.00");
        assertThat(profitAfter.subtract(profitBefore)).isEqualByComparingTo("50.00");
        assertThat(ordersAfter - ordersBefore).isEqualTo(1);
        assertThat(deliveredAfter - deliveredBefore).isEqualTo(1);
        assertThat(linesWithCostAfter - linesWithCostBefore).isEqualTo(1);
        assertThat(linesTotalAfter - linesTotalBefore).isEqualTo(1);
    }

    @SuppressWarnings("unchecked")
    private long deliveredCount(String dashboardJson) {
        List<Map<String, Object>> rows =
                JsonPath.read(dashboardJson, "$.data.ordersByStatus[?(@.status == 'DELIVERED')]");
        return ((Number) rows.get(0).get("count")).longValue();
    }

    /**
     * {@code GET /admin/dashboard} with a CUSTOMER token is denied {@code 403}.
     */
    @Test
    void dashboardAsCustomerReturns403() throws Exception {
        mockMvc.perform(get("/api/v1/admin/dashboard").header(HttpHeaders.AUTHORIZATION, ownerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));
    }

    /**
     * {@code GET /admin/dashboard} without a token is {@code 401}.
     */
    @Test
    void dashboardUnauthenticatedReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/admin/dashboard"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
    }
}
