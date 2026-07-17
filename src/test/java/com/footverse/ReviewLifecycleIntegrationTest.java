package com.footverse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDateTime;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.common.security.JwtUtil;
import com.footverse.support.AuthFixtures;
import com.footverse.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;

/**
 * End-to-end review lifecycle through the real filter chain, services, and database (no mocks,
 * sprint-5-plan item 10). An ADMIN seeds a catalog and a CUSTOMER checks out; the test then proves
 * the whole review surface against live data:
 *
 * <ul>
 *   <li>the eligibility gate — a review attempted <em>before</em> the order is {@code DELIVERED}
 *       is the enveloped {@code 403 REVIEW_NOT_ELIGIBLE};</li>
 *   <li>after an ADMIN walks the order to {@code DELIVERED}, the review is created ({@code 201});</li>
 *   <li>the duplicate guard at the <strong>database</strong> layer — a second review of the same
 *       product is the enveloped {@code 409 REVIEW_DUPLICATED} (the {@code uk_review_user_id_product_id}
 *       constraint behind the service check);</li>
 *   <li>the anonymous public listing returns the review;</li>
 *   <li>the product detail's live {@code averageRating} / {@code reviewCount} reflect the review,
 *       change when it is edited, and return to {@code 0.00} / {@code 0} once it is deleted;</li>
 *   <li>editing moves {@code updatedAt} past the immutable {@code createdAt} (the "edited" indicator).</li>
 * </ul>
 *
 * <p>The flow spans the catalog, cart, address, order, and review modules, so it lives in the root
 * test package alongside the other cross-module flows. ADMIN accounts are provisioned outside the API
 * (user management is Future), so the fixtures persist both users directly. Runs in a rolled-back
 * transaction so no state leaks.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class ReviewLifecycleIntegrationTest {

    private static final String ADMIN_EMAIL = "review-admin@example.com";
    private static final String ADMIN_PHONE = "0900000090";
    private static final String CUSTOMER_EMAIL = "review-customer@example.com";
    private static final String CUSTOMER_PHONE = "0900000091";

    private static final String ADDRESS_BODY = """
            {"recipientName":"Jane Doe","recipientPhone":"0912345678","province":"HCM",
             "district":"D1","ward":"W1","streetAddress":"1 Nguyen Hue"}
            """;

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;

    /** The reviewing customer's id, captured on persist to assert the review's {@code userId} (item 01). */
    private long customerId;

    ReviewLifecycleIntegrationTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil,
            @Autowired UserRepository userRepository) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }

    @BeforeEach
    void persistUsers() {
        userRepository.save(AuthFixtures.admin(ADMIN_EMAIL, ADMIN_PHONE));
        customerId = userRepository.save(AuthFixtures.customer(CUSTOMER_EMAIL, CUSTOMER_PHONE)).getId();
    }

    private String adminToken() {
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private String customerToken() {
        return "Bearer " + jwtUtil.createAccessToken(CUSTOMER_EMAIL);
    }

    /** Performs an authenticated {@code POST} that must answer {@code 201 Created} and yields the id. */
    private long create(String path, String token, String json) throws Exception {
        String body = mockMvc.perform(post(path)
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.data.id")).longValue();
    }

    /** Adds the given variant and quantity to the customer's cart. */
    private void addToCart(long variantId, int quantity) throws Exception {
        mockMvc.perform(post("/api/v1/cart/items")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productVariantId\":" + variantId + ",\"quantity\":" + quantity + "}"))
                .andExpect(status().isOk());
    }

    /** Reads the caller's cart and returns the cart-line id holding the given variant. */
    private long cartItemIdForVariant(long variantId) throws Exception {
        String body = mockMvc.perform(get("/api/v1/cart").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return ((Number) ((java.util.List<?>) JsonPath.read(body,
                "$.data.items[?(@.productVariantId == " + variantId + ")].id")).get(0)).longValue();
    }

    /** Advances an order's status as ADMIN, asserting {@code 200 OK}. */
    private ResultActions patchStatus(long orderId, String status) throws Exception {
        return mockMvc.perform(patch("/api/v1/orders/" + orderId + "/status")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"" + status + "\"}"))
                .andExpect(status().isOk());
    }

    /** Reads the public product detail and asserts the live rating aggregate. */
    private void assertProductRating(long productId, double averageRating, int reviewCount) throws Exception {
        mockMvc.perform(get("/api/v1/products/" + productId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.averageRating").value(averageRating))
                .andExpect(jsonPath("$.data.reviewCount").value(reviewCount));
    }

    /**
     * Walks the whole review lifecycle: eligibility before delivery, create after delivery, the
     * duplicate database backstop, the anonymous listing, the live product-rating aggregate through
     * create / edit / delete, and the {@code updatedAt} move on edit.
     */
    @Test
    void customerReviewsADeliveredProductThroughCreateEditDelete() throws Exception {
        // 1. ADMIN seeds the catalog: category, brand, product, one ACTIVE in-stock variant, image.
        long categoryId = create("/api/v1/categories", adminToken(),
                "{\"name\":\"Review Sneakers\",\"description\":\"flow category\"}");
        long brandId = create("/api/v1/brands", adminToken(), "{\"name\":\"Review Nike\"}");
        long productId = create("/api/v1/products", adminToken(),
                "{\"name\":\"FV Review Runner\",\"description\":\"flow product\",\"basePrice\":200000.00,"
                        + "\"categoryId\":" + categoryId + ",\"brandId\":" + brandId + "}");
        long variantId = create("/api/v1/products/" + productId + "/variants", adminToken(),
                "{\"color\":\"Black\",\"size\":\"42\",\"stockQuantity\":10,\"sku\":\"FV-RV-A\",\"status\":\"ACTIVE\"}");
        create("/api/v1/products/" + productId + "/images", adminToken(),
                "{\"imageUrl\":\"http://img/review-primary.png\",\"displayOrder\":0,\"isPrimary\":true}");

        // 2. The CUSTOMER creates a shipping address, carts the variant, and checks out.
        long addressId = create("/api/v1/addresses", customerToken(), ADDRESS_BODY);
        addToCart(variantId, 1);
        long cartItemId = cartItemIdForVariant(variantId);
        long orderId = create("/api/v1/orders", customerToken(),
                "{\"cartItemIds\":[" + cartItemId + "],\"addressId\":" + addressId + "}");

        String reviewBody = "{\"productId\":" + productId + ",\"rating\":5,\"comment\":\"Excellent shoe\"}";

        // 3. Eligibility gate: reviewing before the order is DELIVERED is 403 REVIEW_NOT_ELIGIBLE.
        mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reviewBody))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_NOT_ELIGIBLE"));

        // 4. An ADMIN walks the order through the status machine to DELIVERED.
        patchStatus(orderId, "CONFIRMED");
        patchStatus(orderId, "SHIPPING");
        patchStatus(orderId, "DELIVERED")
                .andExpect(jsonPath("$.data.status").value("DELIVERED"))
                // OrderItemResponse.productId (item 01): the delivered line exposes its owning product id,
                // resolved live from the variant — the eligibility-clear path from an order line to review.
                .andExpect(jsonPath("$.data.items[0].productId").value((int) productId));

        // 5. Now the CUSTOMER can create the review (201); capture its id and audit timestamps.
        String createdJson = mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reviewBody))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.rating").value(5))
                .andExpect(jsonPath("$.data.comment").value("Excellent shoe"))
                .andExpect(jsonPath("$.data.userFullName").value(AuthFixtures.FULL_NAME))
                // ReviewResponse.productId / userId (item 01): the review links to its product and its
                // author, so the client can recognise the caller's own review across sessions.
                .andExpect(jsonPath("$.data.productId").value((int) productId))
                .andExpect(jsonPath("$.data.userId").value((int) customerId))
                .andReturn().getResponse().getContentAsString();
        long reviewId = ((Number) JsonPath.read(createdJson, "$.data.id")).longValue();
        LocalDateTime createdAt = LocalDateTime.parse(JsonPath.read(createdJson, "$.data.createdAt"));

        // 6. The duplicate guard (database backstop behind the service check): a second review is 409.
        mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(reviewBody))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_DUPLICATED"));

        // 7. The anonymous public listing returns the single review, newest-first.
        mockMvc.perform(get("/api/v1/products/" + productId + "/reviews"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(1))
                .andExpect(jsonPath("$.data.content[0].id").value((int) reviewId))
                .andExpect(jsonPath("$.data.content[0].rating").value(5));

        // 8. The public product detail carries the live aggregate: one 5-star review.
        assertProductRating(productId, 5.0, 1);

        // 9. The owner edits the review: rating drops to 4, updatedAt moves past the immutable createdAt.
        String editedJson = mockMvc.perform(put("/api/v1/reviews/" + reviewId)
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":4,\"comment\":\"Good after a week\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.rating").value(4))
                .andExpect(jsonPath("$.data.comment").value("Good after a week"))
                .andReturn().getResponse().getContentAsString();
        LocalDateTime editedCreatedAt = LocalDateTime.parse(JsonPath.read(editedJson, "$.data.createdAt"));
        LocalDateTime editedUpdatedAt = LocalDateTime.parse(JsonPath.read(editedJson, "$.data.updatedAt"));
        assertThat(editedCreatedAt).isEqualTo(createdAt);
        assertThat(editedUpdatedAt).isAfter(createdAt);

        // 10. The aggregate now reflects the edited rating.
        assertProductRating(productId, 4.0, 1);

        // 11. The owner deletes the review.
        mockMvc.perform(delete("/api/v1/reviews/" + reviewId).header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk());

        // 12. The review drops out of the listing and the aggregate returns to 0.00 / 0.
        mockMvc.perform(get("/api/v1/products/" + productId + "/reviews"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content.length()").value(0));
        assertProductRating(productId, 0.0, 0);
    }
}
