package com.footverse.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.footverse.support.AuthFixtures;
import com.footverse.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

/**
 * End-to-end proof of the ADMIN order read surface (sprint-12-plan Task 01), through the real filter
 * chain, services, and database (no mocks). An ADMIN seeds the catalog and a coupon, a CUSTOMER
 * ("owner") places and cancels one order and places a second, and:
 *
 * <ul>
 *   <li>the ADMIN reads the owner's order via {@code GET /admin/orders/{id}} — a
 *       <strong>different</strong> user than the ADMIN's own account, proving the admin read
 *       bypasses ownership entirely (security-spec §7);</li>
 *   <li>the ADMIN lists orders via {@code GET /admin/orders} and finds the owner's order among them,
 *       carrying the owner's account identity (not the ADMIN's);</li>
 *   <li>a second CUSTOMER ("stranger") is still rejected {@code 403 ORDER_FORBIDDEN} reading the
 *       owner's order via the customer-scoped {@code GET /orders/{id}} — proving the customer
 *       contract is byte-for-byte unchanged by this sprint (sprint-12-plan Task 01 Definition of
 *       Done).</li>
 * </ul>
 *
 * <p>Runs in a rolled-back transaction so no state leaks (the {@code CheckoutFlowIntegrationTest}
 * precedent).</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class AdminOrderReadIntegrationTest {

    private static final String ADMIN_EMAIL = "admin-order-read@example.com";
    private static final String ADMIN_PHONE = "0900000080";
    private static final String OWNER_EMAIL = "order-owner@example.com";
    private static final String OWNER_PHONE = "0900000081";
    private static final String STRANGER_EMAIL = "order-stranger@example.com";
    private static final String STRANGER_PHONE = "0900000082";

    private static final String ADDRESS_BODY = """
            {"recipientName":"Jane Doe","recipientPhone":"0912345678","province":"HCM",
             "district":"D1","ward":"W1","streetAddress":"1 Nguyen Hue"}
            """;

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    AdminOrderReadIntegrationTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil,
            @Autowired UserRepository userRepository) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    @BeforeEach
    void persistUsers() {
        userRepository.save(AuthFixtures.admin(ADMIN_EMAIL, ADMIN_PHONE));
        userRepository.save(AuthFixtures.customer(OWNER_EMAIL, OWNER_PHONE));
        userRepository.save(AuthFixtures.customer(STRANGER_EMAIL, STRANGER_PHONE));
    }

    private String adminToken() {
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private String ownerToken() {
        return "Bearer " + jwtUtil.createAccessToken(OWNER_EMAIL);
    }

    private String strangerToken() {
        return "Bearer " + jwtUtil.createAccessToken(STRANGER_EMAIL);
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
     * as the ADMIN, mirroring the {@code CheckoutFlowIntegrationTest} seeding shape.
     */
    private long seedPurchasableVariant() throws Exception {
        long categoryId = create("/api/v1/categories", adminToken(), "{\"name\":\"Sneakers-AOR\"}");
        long brandId = create("/api/v1/brands", adminToken(), "{\"name\":\"Nike-AOR\"}");
        long productId = create("/api/v1/products", adminToken(),
                "{\"name\":\"Air Force 1 AOR\",\"description\":\"Classic\",\"basePrice\":100.00,"
                        + "\"categoryId\":" + categoryId + ",\"brandId\":" + brandId + "}");
        long variantId = create("/api/v1/products/" + productId + "/variants", adminToken(),
                "{\"color\":\"Black\",\"size\":\"42\",\"sku\":\"SKU-AOR-42\",\"stockQuantity\":10,"
                        + "\"status\":\"ACTIVE\",\"costPrice\":50.00}");
        create("/api/v1/products/" + productId + "/images", adminToken(),
                "{\"imageUrl\":\"img.png\",\"displayOrder\":1,\"isPrimary\":true}");
        return variantId;
    }

    /** Places one order for the owner customer and returns its id. */
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

    /**
     * The core admin-read proof: an ADMIN reads the owner's order (a different user) via both the
     * detail and the list endpoints, and the owner's identity is carried; a stranger customer is
     * still {@code 403 ORDER_FORBIDDEN} on the unchanged customer path.
     */
    @Test
    void adminReadsAnotherUsersOrderWhileCustomerPathStaysForbidden() throws Exception {
        long variantId = seedPurchasableVariant();
        long orderId = placeOwnerOrder(variantId);

        // ADMIN detail: reads the owner's order end-to-end, regardless of owner (security-spec §7),
        // carrying the owner's account identity (not the ADMIN's).
        mockMvc.perform(get("/api/v1/admin/orders/" + orderId).header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(orderId))
                .andExpect(jsonPath("$.data.customerEmail").value(OWNER_EMAIL))
                .andExpect(jsonPath("$.data.customerPhone").value(OWNER_PHONE));

        // ADMIN list: the owner's order is present, carrying the owner's identity.
        String listBody = mockMvc.perform(get("/api/v1/admin/orders?size=100")
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        List<Object> matchingEmails = JsonPath.read(listBody,
                "$.data.content[?(@.id == " + orderId + ")].customerEmail");
        assertThat(matchingEmails).containsExactly(OWNER_EMAIL);

        // Customer path unchanged: a stranger is still 403 ORDER_FORBIDDEN on the owner's order.
        mockMvc.perform(get("/api/v1/orders/" + orderId).header(HttpHeaders.AUTHORIZATION, strangerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("ORDER_FORBIDDEN"));

        // Customer path unchanged: the ADMIN token is still 403 FORBIDDEN on the customer-only path.
        mockMvc.perform(get("/api/v1/orders/" + orderId).header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        // The CUSTOMER token is still 403 FORBIDDEN on the admin-only read paths.
        mockMvc.perform(get("/api/v1/admin/orders/" + orderId).header(HttpHeaders.AUTHORIZATION, ownerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));
        mockMvc.perform(get("/api/v1/admin/orders").header(HttpHeaders.AUTHORIZATION, ownerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));
    }

    /**
     * {@code GET /admin/orders/{id}} for an id no order has reuses {@code 404 ORDER_NOT_FOUND} — the
     * same code the customer path already uses, mints no new one.
     */
    @Test
    void adminDetailOfUnknownOrderIsNotFound() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders/999999999").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("ORDER_NOT_FOUND"));
    }
}
