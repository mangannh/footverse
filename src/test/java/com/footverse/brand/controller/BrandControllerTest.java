package com.footverse.brand.controller;

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

import com.footverse.brand.dto.BrandResponse;
import com.footverse.brand.service.BrandService;
import com.footverse.common.config.SecurityConfig;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.InvalidOperationException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for {@link BrandController}: the public listing, the admin write endpoints
 * (ADMIN passes, CUSTOMER is denied {@code 403}), request-body validation, and the business
 * conflicts ({@code BRAND_NAME_DUPLICATED}, {@code BRAND_IN_USE}) rendered as the enveloped
 * {@code 409}. The security filter chain is imported; the service is mocked.
 */
@WebMvcTest(BrandController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class BrandControllerTest {

    private static final String ADMIN_EMAIL = "admin@example.com";
    private static final String CUSTOMER_EMAIL = "customer@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private BrandService brandService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    BrandControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
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

    /**
     * {@code GET /brands} is public and returns the enveloped list.
     */
    @Test
    void listBrandsPublicReturns200() throws Exception {
        when(brandService.getAllBrands()).thenReturn(List.of(new BrandResponse(1L, "Nike", "logo.png", "desc")));

        mockMvc.perform(get("/api/v1/brands"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data[0].id").value(1))
                .andExpect(jsonPath("$.data[0].name").value("Nike"));
    }

    /**
     * {@code POST /brands} with an ADMIN token creates and returns {@code 201}.
     */
    @Test
    void createBrandAsAdminReturns201() throws Exception {
        when(brandService.createBrand(any())).thenReturn(new BrandResponse(1L, "Nike", "logo.png", "desc"));

        mockMvc.perform(post("/api/v1/brands")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Nike\",\"logoUrl\":\"logo.png\",\"description\":\"desc\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.message").value("Created"))
                .andExpect(jsonPath("$.data.name").value("Nike"));
    }

    /**
     * {@code POST /brands} with a CUSTOMER token is denied the enveloped {@code 403}.
     */
    @Test
    void createBrandAsCustomerReturns403() throws Exception {
        mockMvc.perform(post("/api/v1/brands")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Nike\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        verify(brandService, never()).createBrand(any());
    }

    /**
     * {@code POST /brands} with a blank name fails Bean Validation with {@code 400}.
     */
    @Test
    void createBrandWithInvalidBodyReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/brands")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(brandService, never()).createBrand(any());
    }

    /**
     * A duplicate name from the service is rendered as the enveloped {@code 409}.
     */
    @Test
    void createDuplicateBrandReturns409() throws Exception {
        when(brandService.createBrand(any()))
                .thenThrow(new DuplicateResourceException("BRAND_NAME_DUPLICATED", "Brand name already exists"));

        mockMvc.perform(post("/api/v1/brands")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Nike\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("BRAND_NAME_DUPLICATED"));
    }

    /**
     * {@code PUT /brands/{id}} with an ADMIN token updates and returns {@code 200}.
     */
    @Test
    void updateBrandAsAdminReturns200() throws Exception {
        when(brandService.updateBrand(eq(1L), any())).thenReturn(new BrandResponse(1L, "Adidas", "a.png", "x"));

        mockMvc.perform(put("/api/v1/brands/1")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Adidas\",\"logoUrl\":\"a.png\",\"description\":\"x\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Adidas"));
    }

    /**
     * {@code DELETE /brands/{id}} with an ADMIN token returns the enveloped {@code 200 Void}.
     */
    @Test
    void deleteBrandAsAdminReturns200() throws Exception {
        mockMvc.perform(delete("/api/v1/brands/1").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        verify(brandService).deleteBrand(1L);
    }

    /**
     * Deleting a still-referenced brand surfaces the service's {@code 409 BRAND_IN_USE}.
     */
    @Test
    void deleteReferencedBrandReturns409() throws Exception {
        org.mockito.Mockito.doThrow(new InvalidOperationException("BRAND_IN_USE",
                        "Brand is still referenced by products"))
                .when(brandService).deleteBrand(1L);

        mockMvc.perform(delete("/api/v1/brands/1").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("BRAND_IN_USE"));
    }
}
