package com.footverse.category.controller;

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

import com.footverse.category.dto.CategoryResponse;
import com.footverse.category.service.CategoryService;
import com.footverse.common.config.SecurityConfig;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.InvalidOperationException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for {@link CategoryController}: the public listing, the admin write endpoints
 * (ADMIN passes, CUSTOMER is denied {@code 403}), request-body validation, and the business
 * conflicts ({@code CATEGORY_NAME_DUPLICATED}, {@code CATEGORY_IN_USE}) rendered as the enveloped
 * {@code 409}. The security filter chain is imported; the service is mocked.
 */
@WebMvcTest(CategoryController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class CategoryControllerTest {

    private static final String ADMIN_EMAIL = "admin@example.com";
    private static final String CUSTOMER_EMAIL = "customer@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private CategoryService categoryService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    CategoryControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
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
     * {@code GET /categories} is public and returns the enveloped list.
     */
    @Test
    void listCategoriesPublicReturns200() throws Exception {
        when(categoryService.getAllCategories()).thenReturn(List.of(new CategoryResponse(1L, "Sneakers", "desc")));

        mockMvc.perform(get("/api/v1/categories"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data[0].id").value(1))
                .andExpect(jsonPath("$.data[0].name").value("Sneakers"));
    }

    /**
     * {@code POST /categories} with an ADMIN token creates and returns {@code 201}.
     */
    @Test
    void createCategoryAsAdminReturns201() throws Exception {
        when(categoryService.createCategory(any())).thenReturn(new CategoryResponse(1L, "Sneakers", "desc"));

        mockMvc.perform(post("/api/v1/categories")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Sneakers\",\"description\":\"desc\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.message").value("Created"))
                .andExpect(jsonPath("$.data.name").value("Sneakers"));
    }

    /**
     * {@code POST /categories} with a CUSTOMER token is denied the enveloped {@code 403}.
     */
    @Test
    void createCategoryAsCustomerReturns403() throws Exception {
        mockMvc.perform(post("/api/v1/categories")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Sneakers\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        verify(categoryService, never()).createCategory(any());
    }

    /**
     * {@code POST /categories} with a blank name fails Bean Validation with {@code 400}.
     */
    @Test
    void createCategoryWithInvalidBodyReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/categories")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(categoryService, never()).createCategory(any());
    }

    /**
     * A duplicate name from the service is rendered as the enveloped {@code 409}.
     */
    @Test
    void createDuplicateCategoryReturns409() throws Exception {
        when(categoryService.createCategory(any()))
                .thenThrow(new DuplicateResourceException("CATEGORY_NAME_DUPLICATED", "Category name already exists"));

        mockMvc.perform(post("/api/v1/categories")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Sneakers\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("CATEGORY_NAME_DUPLICATED"));
    }

    /**
     * {@code PUT /categories/{id}} with an ADMIN token updates and returns {@code 200}.
     */
    @Test
    void updateCategoryAsAdminReturns200() throws Exception {
        when(categoryService.updateCategory(eq(1L), any())).thenReturn(new CategoryResponse(1L, "Boots", "x"));

        mockMvc.perform(put("/api/v1/categories/1")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Boots\",\"description\":\"x\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.name").value("Boots"));
    }

    /**
     * {@code DELETE /categories/{id}} with an ADMIN token returns the enveloped {@code 200 Void}.
     */
    @Test
    void deleteCategoryAsAdminReturns200() throws Exception {
        mockMvc.perform(delete("/api/v1/categories/1").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        verify(categoryService).deleteCategory(1L);
    }

    /**
     * Deleting a still-referenced category surfaces the service's {@code 409 CATEGORY_IN_USE}.
     */
    @Test
    void deleteReferencedCategoryReturns409() throws Exception {
        org.mockito.Mockito.doThrow(new InvalidOperationException("CATEGORY_IN_USE",
                        "Category is still referenced by products"))
                .when(categoryService).deleteCategory(1L);

        mockMvc.perform(delete("/api/v1/categories/1").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("CATEGORY_IN_USE"));
    }
}
