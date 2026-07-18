package com.footverse.product.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.footverse.common.config.SecurityConfig;
import com.footverse.common.dto.PageResponse;
import com.footverse.common.exception.ResourceNotFoundException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.product.dto.AdminProductDetailResponse;
import com.footverse.product.dto.AdminProductSummaryResponse;
import com.footverse.product.dto.AdminProductVariantResponse;
import com.footverse.product.entity.ProductVariantStatus;
import com.footverse.product.service.ProductService;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for {@link AdminProductController}: the ADMIN product read surface returns
 * {@code 200} with the ADMIN DTOs (variants carrying {@code costPrice}) for an ADMIN, is denied
 * {@code 403} for a CUSTOMER and {@code 401} when unauthenticated, and reuses
 * {@code 404 PRODUCT_NOT_FOUND} for a missing product. The security filter chain is imported so
 * authorization is exercised; the service layer is mocked.
 */
@WebMvcTest(AdminProductController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class AdminProductControllerTest {

    private static final String ADMIN_EMAIL = "admin@example.com";
    private static final String CUSTOMER_EMAIL = "customer@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private ProductService productService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    AdminProductControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
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

    private AdminProductDetailResponse detailWithCost() {
        AdminProductVariantResponse variant = new AdminProductVariantResponse(2L, "Black", "42",
                new BigDecimal("100.00"), null, new BigDecimal("80.00"), 5, ProductVariantStatus.ACTIVE, "SKU-42");
        return new AdminProductDetailResponse(1L, "Air Force 1", "Classic", new BigDecimal("100.00"),
                5L, "Nike", 3L, "Sneakers", List.of(), List.of(variant), new BigDecimal("0.00"), 0, true,
                LocalDateTime.now());
    }

    /**
     * {@code GET /admin/products} with an ADMIN token returns {@code 200} and the enveloped page.
     */
    @Test
    void listAsAdminReturns200() throws Exception {
        AdminProductSummaryResponse summary = new AdminProductSummaryResponse(1L, "Air Force 1",
                new BigDecimal("100.00"), "Nike", "Sneakers", "img.png", new BigDecimal("0.00"), true);
        when(productService.getAdminProducts(any()))
                .thenReturn(new PageResponse<>(List.of(summary), 0, 20, 1, 1, true));

        mockMvc.perform(get("/api/v1/admin/products").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.content[0].name").value("Air Force 1"));
    }

    /**
     * {@code GET /admin/products} with a CUSTOMER token is denied {@code 403}.
     */
    @Test
    void listAsCustomerReturns403() throws Exception {
        mockMvc.perform(get("/api/v1/admin/products").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isForbidden());
    }

    /**
     * {@code GET /admin/products} without a token is {@code 401}.
     */
    @Test
    void listUnauthenticatedReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/admin/products"))
                .andExpect(status().isUnauthorized());
    }

    /**
     * {@code GET /admin/products/{id}} with an ADMIN token returns {@code 200} and the detail whose
     * variants carry {@code costPrice}.
     */
    @Test
    void detailAsAdminReturns200WithCostPrice() throws Exception {
        when(productService.getAdminProductDetail(1L)).thenReturn(detailWithCost());

        mockMvc.perform(get("/api/v1/admin/products/1").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.variants[0].costPrice").value(80.00))
                .andExpect(jsonPath("$.data.variants[0].sku").value("SKU-42"));
    }

    /**
     * {@code GET /admin/products/{id}} with a CUSTOMER token is denied {@code 403}.
     */
    @Test
    void detailAsCustomerReturns403() throws Exception {
        mockMvc.perform(get("/api/v1/admin/products/1").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isForbidden());
    }

    /**
     * {@code GET /admin/products/{id}} for a missing product reuses {@code 404 PRODUCT_NOT_FOUND}.
     */
    @Test
    void detailNotFoundReturns404() throws Exception {
        when(productService.getAdminProductDetail(eq(9L)))
                .thenThrow(new ResourceNotFoundException("PRODUCT_NOT_FOUND", "Product not found"));

        mockMvc.perform(get("/api/v1/admin/products/9").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PRODUCT_NOT_FOUND"));
    }
}
