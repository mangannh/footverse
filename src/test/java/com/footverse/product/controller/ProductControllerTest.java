package com.footverse.product.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.footverse.common.config.SecurityConfig;
import com.footverse.common.dto.PageResponse;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.product.dto.ProductDetailResponse;
import com.footverse.product.dto.ProductImageResponse;
import com.footverse.product.dto.ProductSummaryResponse;
import com.footverse.product.dto.ProductVariantResponse;
import com.footverse.product.entity.ProductVariantStatus;
import com.footverse.product.service.ProductService;
import com.footverse.product.service.ProductVariantService;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for {@link ProductController}: public search/detail, the admin write endpoints
 * (ADMIN passes, CUSTOMER is denied {@code 403}), request-body and query-parameter validation, and
 * the response envelope/status per dto-spec §20. The security filter chain is imported so
 * authorization is exercised; the service layer is mocked.
 */
@WebMvcTest(ProductController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class ProductControllerTest {

    private static final String ADMIN_EMAIL = "admin@example.com";
    private static final String CUSTOMER_EMAIL = "customer@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private ProductService productService;

    @MockitoBean
    private ProductVariantService productVariantService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    ProductControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
    }

    private String adminToken() {
        when(userDetailsService.loadUserByUsername(ADMIN_EMAIL))
                .thenReturn(AuthFixtures.userDetails(ADMIN_EMAIL, Role.ADMIN));
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private String customerToken() {
        when(userDetailsService.loadUserByUsername(CUSTOMER_EMAIL))
                .thenReturn(AuthFixtures.userDetails(CUSTOMER_EMAIL, Role.CUSTOMER));
        return "Bearer " + jwtUtil.createAccessToken(CUSTOMER_EMAIL);
    }

    private ProductDetailResponse detail() {
        return new ProductDetailResponse(1L, "Air Force 1", "Classic", new BigDecimal("100.00"),
                5L, "Nike", 3L, "Sneakers", List.of(), List.of(), new BigDecimal("0.00"), 0, false,
                LocalDateTime.now());
    }

    // ----- Public reads -----

    /**
     * {@code GET /products} is public, returns {@code 200} and the enveloped page of summaries.
     */
    @Test
    void searchProductsPublicReturns200() throws Exception {
        ProductSummaryResponse summary = new ProductSummaryResponse(1L, "Air Force 1",
                new BigDecimal("100.00"), "Nike", "Sneakers", "img.png", new BigDecimal("0.00"), true);
        PageResponse<ProductSummaryResponse> page = new PageResponse<>(List.of(summary), 0, 20, 1, 1, true);
        when(productService.searchProducts(any(), any(), any(), any())).thenReturn(page);

        mockMvc.perform(get("/api/v1/products"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.content[0].id").value(1))
                .andExpect(jsonPath("$.data.content[0].name").value("Air Force 1"))
                .andExpect(jsonPath("$.data.totalElements").value(1))
                .andExpect(jsonPath("$.data.page").value(0));
    }

    /**
     * {@code GET /products/{id}} is public, returns {@code 200} and the enveloped detail.
     */
    @Test
    void getProductDetailPublicReturns200() throws Exception {
        when(productService.getProductDetail(1L)).thenReturn(detail());

        mockMvc.perform(get("/api/v1/products/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(1))
                .andExpect(jsonPath("$.data.brandName").value("Nike"))
                .andExpect(jsonPath("$.data.categoryName").value("Sneakers"));
    }

    /**
     * A non-whitelisted sort key is rejected with the enveloped {@code 400} from the service.
     */
    @Test
    void searchProductsInvalidSortReturns400() throws Exception {
        when(productService.searchProducts(any(), any(), any(), any()))
                .thenThrow(new com.footverse.common.exception.BusinessException(
                        org.springframework.http.HttpStatus.BAD_REQUEST, "PRODUCT_SORT_INVALID",
                        "Sort is only allowed by: createdAt, basePrice, name"));

        mockMvc.perform(get("/api/v1/products").param("sort", "price,desc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("PRODUCT_SORT_INVALID"));
    }

    /**
     * A query parameter that violates its constraint ({@code brandId} must be positive) is rejected
     * with the enveloped {@code 400 VALIDATION_ERROR} at the boundary.
     */
    @Test
    void searchProductsInvalidQueryParamReturns400() throws Exception {
        mockMvc.perform(get("/api/v1/products").param("brandId", "0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(productService, never()).searchProducts(any(), any(), any(), any());
    }

    /**
     * A query parameter of the wrong type ({@code brandId=abc}) is rejected with the enveloped
     * {@code 400 VALIDATION_ERROR}.
     */
    @Test
    void searchProductsTypeMismatchReturns400() throws Exception {
        mockMvc.perform(get("/api/v1/products").param("brandId", "abc"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(productService, never()).searchProducts(any(), any(), any(), any());
    }

    // ----- Admin product writes -----

    /**
     * {@code POST /products} with an ADMIN token creates the product and returns {@code 201}.
     */
    @Test
    void createProductAsAdminReturns201() throws Exception {
        when(productService.createProduct(any())).thenReturn(detail());

        mockMvc.perform(post("/api/v1/products")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Air Force 1\",\"description\":\"Classic\","
                                + "\"basePrice\":100.00,\"categoryId\":3,\"brandId\":5}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("Created"))
                .andExpect(jsonPath("$.data.id").value(1));
    }

    /**
     * {@code POST /products} with a CUSTOMER token is denied the enveloped {@code 403} before the
     * service is reached.
     */
    @Test
    void createProductAsCustomerReturns403() throws Exception {
        mockMvc.perform(post("/api/v1/products")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Air Force 1\",\"basePrice\":100.00,\"categoryId\":3,\"brandId\":5}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        verify(productService, never()).createProduct(any());
    }

    /**
     * {@code POST /products} with an invalid body (ADMIN, past authorization) fails Bean Validation
     * with the enveloped {@code 400 VALIDATION_ERROR}.
     */
    @Test
    void createProductWithInvalidBodyReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/products")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"description\":\"missing required fields\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(productService, never()).createProduct(any());
    }

    /**
     * {@code PUT /products/{id}} with an ADMIN token updates and returns {@code 200}.
     */
    @Test
    void updateProductAsAdminReturns200() throws Exception {
        when(productService.updateProduct(eq(1L), any())).thenReturn(detail());

        mockMvc.perform(put("/api/v1/products/1")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Renamed\",\"basePrice\":120.00,\"categoryId\":3,\"brandId\":5}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(1));
    }

    /**
     * {@code DELETE /products/{id}} with an ADMIN token soft-deletes and returns the enveloped
     * {@code 200 Void}.
     */
    @Test
    void deleteProductAsAdminReturns200() throws Exception {
        mockMvc.perform(delete("/api/v1/products/1").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data").doesNotExist());

        verify(productService).deleteProduct(1L);
    }

    // ----- Admin variant writes (delegated to ProductVariantService) -----

    /**
     * {@code POST /products/{id}/variants} with an ADMIN token delegates to
     * {@link ProductVariantService} and returns {@code 201}.
     */
    @Test
    void createVariantAsAdminReturns201() throws Exception {
        ProductVariantResponse variant = new ProductVariantResponse(2L, "42", new BigDecimal("100.00"),
                5, ProductVariantStatus.ACTIVE, "SKU-42");
        when(productVariantService.createVariant(eq(1L), any())).thenReturn(variant);

        mockMvc.perform(post("/api/v1/products/1/variants")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"size\":\"42\",\"stockQuantity\":5,\"sku\":\"SKU-42\",\"status\":\"ACTIVE\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").value(2))
                .andExpect(jsonPath("$.data.sku").value("SKU-42"));

        verify(productVariantService).createVariant(eq(1L), any());
    }

    /**
     * {@code PUT /products/{id}/variants/{variantId}} with an ADMIN token updates and returns
     * {@code 200}.
     */
    @Test
    void updateVariantAsAdminReturns200() throws Exception {
        ProductVariantResponse variant = new ProductVariantResponse(2L, "43", new BigDecimal("100.00"),
                9, ProductVariantStatus.ACTIVE, "SKU-43");
        when(productVariantService.updateVariant(eq(1L), eq(2L), any())).thenReturn(variant);

        mockMvc.perform(put("/api/v1/products/1/variants/2")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"size\":\"43\",\"stockQuantity\":9,\"sku\":\"SKU-43\",\"status\":\"ACTIVE\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.size").value("43"));
    }

    // ----- Admin image writes -----

    /**
     * {@code POST /products/{id}/images} with an ADMIN token creates and returns {@code 201}.
     */
    @Test
    void createImageAsAdminReturns201() throws Exception {
        when(productService.createImage(eq(1L), any())).thenReturn(new ProductImageResponse(2L, "img.png", 0, true));

        mockMvc.perform(post("/api/v1/products/1/images")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"imageUrl\":\"img.png\",\"displayOrder\":0,\"isPrimary\":true}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").value(2))
                .andExpect(jsonPath("$.data.isPrimary").value(true));
    }

    /**
     * {@code PUT /products/{id}/images/{imageId}} with an ADMIN token updates and returns
     * {@code 200}.
     */
    @Test
    void updateImageAsAdminReturns200() throws Exception {
        when(productService.updateImage(eq(1L), eq(2L), any()))
                .thenReturn(new ProductImageResponse(2L, "u.png", 1, false));

        mockMvc.perform(put("/api/v1/products/1/images/2")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"imageUrl\":\"u.png\",\"displayOrder\":1,\"isPrimary\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.imageUrl").value("u.png"));
    }
}
