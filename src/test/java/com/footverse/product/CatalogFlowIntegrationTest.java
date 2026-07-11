package com.footverse.product;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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

import jakarta.persistence.EntityManager;

/**
 * End-to-end catalog lifecycle through the real filter chain, services, and database (no mocks,
 * sprint-2-plan item 12): an ADMIN creates a category, brand, product, variant, and primary image;
 * a public caller lists, searches, and reads the product (seeing it purchasable with its image and
 * variant); and deleting the still-referenced category is blocked with the enveloped
 * {@code 409 CATEGORY_IN_USE} (the frozen {@code product.category_id} foreign key).
 *
 * <p>ADMIN accounts are provisioned outside the API (user management is Future), so the fixtures
 * persist an ADMIN directly. Runs in a rolled-back transaction so no catalog state leaks.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class CatalogFlowIntegrationTest {

    private static final String ADMIN_EMAIL = "catalog-admin@example.com";
    private static final String ADMIN_PHONE = "0900000050";
    private static final String PRODUCT_NAME = "FV Integration Runner";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final EntityManager entityManager;

    CatalogFlowIntegrationTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil,
            @Autowired UserRepository userRepository, @Autowired EntityManager entityManager) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
        this.entityManager = entityManager;
    }

    @BeforeEach
    void persistAdmin() {
        userRepository.save(AuthFixtures.admin(ADMIN_EMAIL, ADMIN_PHONE));
    }

    private String adminToken() {
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private long adminCreate(String path, String json) throws Exception {
        String body = mockMvc.perform(post(path)
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.data.id")).longValue();
    }

    /**
     * Walks the whole catalog lifecycle in one flow and asserts the public reads and the
     * referenced-category delete conflict.
     */
    @Test
    void catalogLifecycleFromAdminCreationToReferencedCategoryDelete() throws Exception {
        // 1-2. ADMIN creates a category and a brand.
        long categoryId = adminCreate("/api/v1/categories",
                "{\"name\":\"Integration Sneakers\",\"description\":\"flow category\"}");
        long brandId = adminCreate("/api/v1/brands",
                "{\"name\":\"Integration Nike\",\"logoUrl\":\"http://img/logo.png\",\"description\":\"flow brand\"}");

        // 3. ADMIN creates a product referencing them.
        long productId = adminCreate("/api/v1/products",
                "{\"name\":\"" + PRODUCT_NAME + "\",\"description\":\"flow product\","
                        + "\"basePrice\":150.00,\"categoryId\":" + categoryId + ",\"brandId\":" + brandId + "}");

        // 4. ADMIN creates an ACTIVE, in-stock variant (makes the product purchasable).
        mockMvc.perform(post("/api/v1/products/" + productId + "/variants")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"color\":\"Black\",\"size\":\"42\",\"stockQuantity\":5,\"sku\":\"FV-INT-42\",\"status\":\"ACTIVE\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.price").value(150.00));

        // 5. ADMIN creates the primary image.
        mockMvc.perform(post("/api/v1/products/" + productId + "/images")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"imageUrl\":\"http://img/primary.png\",\"displayOrder\":0,\"isPrimary\":true}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.isPrimary").value(true));

        // 6a. Public list: the product appears, purchasable, with its primary image.
        mockMvc.perform(get("/api/v1/products"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[0].name").value(PRODUCT_NAME))
                .andExpect(jsonPath("$.data.content[0].available").value(true))
                .andExpect(jsonPath("$.data.content[0].primaryImageUrl").value("http://img/primary.png"));

        // 6b. Public search by partial name (case-insensitive).
        mockMvc.perform(get("/api/v1/products").param("name", "integration runner"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.content[0].id").value((int) productId));

        // 6c. Public detail: assembled with brand/category, the variant, the image, and availability.
        mockMvc.perform(get("/api/v1/products/" + productId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.brandName").value("Integration Nike"))
                .andExpect(jsonPath("$.data.categoryName").value("Integration Sneakers"))
                .andExpect(jsonPath("$.data.variants[0].sku").value("FV-INT-42"))
                .andExpect(jsonPath("$.data.variants[0].price").value(150.00))
                .andExpect(jsonPath("$.data.images[0].imageUrl").value("http://img/primary.png"))
                .andExpect(jsonPath("$.data.available").value(true))
                .andExpect(jsonPath("$.data.averageRating").value(0.00))
                .andExpect(jsonPath("$.data.reviewCount").value(0));

        // Flush the pending inserts and detach them so the delete runs against a clean persistence
        // context — reproducing production, where the delete is a separate transaction. Otherwise the
        // still-managed product would trip an ORM-level check before the database foreign key does.
        entityManager.flush();
        entityManager.clear();

        // 7. Deleting the still-referenced category is blocked by the FK, reported as 409.
        mockMvc.perform(delete("/api/v1/categories/" + categoryId).header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("CATEGORY_IN_USE"));
    }

    /**
     * After a soft delete the product disappears from the public reads: the catalog search excludes
     * it (soft-delete-aware repository query) and its detail resolves to {@code 404}, while the row
     * still exists in the database (business-rules → Product).
     */
    @Test
    void softDeletedProductIsInvisibleToPublicReads() throws Exception {
        long categoryId = adminCreate("/api/v1/categories",
                "{\"name\":\"Soft Delete Category\",\"description\":\"x\"}");
        long brandId = adminCreate("/api/v1/brands", "{\"name\":\"Soft Delete Brand\"}");
        long productId = adminCreate("/api/v1/products",
                "{\"name\":\"Soft Delete Runner\",\"basePrice\":90.00,"
                        + "\"categoryId\":" + categoryId + ",\"brandId\":" + brandId + "}");
        mockMvc.perform(post("/api/v1/products/" + productId + "/variants")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"color\":\"White\",\"size\":\"41\",\"stockQuantity\":3,\"sku\":\"SD-41\",\"status\":\"ACTIVE\"}"))
                .andExpect(status().isCreated());

        // Visible before deletion.
        mockMvc.perform(get("/api/v1/products").param("name", "Soft Delete Runner"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(1));

        // ADMIN soft-deletes the product.
        mockMvc.perform(delete("/api/v1/products/" + productId).header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk());

        // Search now excludes it, and the detail is a 404 — the row remains but reads treat it absent.
        mockMvc.perform(get("/api/v1/products").param("name", "Soft Delete Runner"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.totalElements").value(0));
        mockMvc.perform(get("/api/v1/products/" + productId))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PRODUCT_NOT_FOUND"));
    }
}
