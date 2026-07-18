package com.footverse.order.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
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
import org.springframework.data.domain.Pageable;
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
import com.footverse.order.dto.AdminOrderDetailResponse;
import com.footverse.order.dto.AdminOrderSummaryResponse;
import com.footverse.order.dto.OrderItemResponse;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentMethod;
import com.footverse.order.entity.PaymentStatus;
import com.footverse.order.service.OrderService;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for {@link AdminOrderController}: the ADMIN order read surface returns
 * {@code 200} with the ADMIN DTOs (carrying the owning customer's identity) for an ADMIN, is denied
 * {@code 403} for a CUSTOMER and {@code 401} when unauthenticated, binds the {@code status} /
 * {@code orderCode} query params, and reuses {@code 404 ORDER_NOT_FOUND} for a missing order. The
 * security filter chain is imported so authorization is exercised; the service layer is mocked.
 */
@WebMvcTest(AdminOrderController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class AdminOrderControllerTest {

    private static final String ADMIN_EMAIL = "admin@example.com";
    private static final String CUSTOMER_EMAIL = "customer@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private OrderService orderService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    AdminOrderControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
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

    private AdminOrderSummaryResponse summary() {
        return new AdminOrderSummaryResponse(5L, "FV-ORDER-5", OrderStatus.PENDING, PaymentStatus.UNPAID,
                new BigDecimal("30200.00"), 5, LocalDateTime.now(), 42L, "Jane Doe", "jane@example.com",
                "0900000001");
    }

    private AdminOrderDetailResponse detail() {
        OrderItemResponse item = new OrderItemResponse(1L, 7L, 100L, "Air Force 1", "img.png", "Black", "42",
                new BigDecimal("100.00"), 2, new BigDecimal("200.00"));
        return new AdminOrderDetailResponse(9L, "FV-ORDER-9", OrderStatus.PENDING, PaymentMethod.COD,
                PaymentStatus.UNPAID, new BigDecimal("200.00"), BigDecimal.ZERO, new BigDecimal("30000.00"),
                new BigDecimal("30200.00"), null, "Jane", "0900000000", "HCM", "D1", "W1", "1 Street",
                null, List.of(item), LocalDateTime.now(), null, null, 999L, "Someone Else",
                "someone@example.com", "0900000099");
    }

    /**
     * {@code GET /admin/orders} with an ADMIN token returns {@code 200} and the enveloped page,
     * each row carrying the owning customer's identity.
     */
    @Test
    void listAsAdminReturns200WithCustomerIdentity() throws Exception {
        when(orderService.adminListOrders(isNull(), isNull(), any(Pageable.class)))
                .thenReturn(new PageResponse<>(List.of(summary()), 0, 20, 1, 1, true));

        mockMvc.perform(get("/api/v1/admin/orders").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.content[0].orderCode").value("FV-ORDER-5"))
                .andExpect(jsonPath("$.data.content[0].customerId").value(42))
                .andExpect(jsonPath("$.data.content[0].customerFullName").value("Jane Doe"))
                .andExpect(jsonPath("$.data.content[0].customerEmail").value("jane@example.com"))
                .andExpect(jsonPath("$.data.content[0].customerPhone").value("0900000001"));
    }

    /**
     * {@code GET /admin/orders?status=X&orderCode=Y} binds both query params and passes them to the
     * service unchanged.
     */
    @Test
    void listWithStatusAndOrderCodeBindsBothParams() throws Exception {
        when(orderService.adminListOrders(eq(OrderStatus.DELIVERED), eq("FV-2026"), any(Pageable.class)))
                .thenReturn(new PageResponse<>(List.of(), 0, 20, 0, 0, true));

        mockMvc.perform(get("/api/v1/admin/orders?status=DELIVERED&orderCode=FV-2026")
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk());
    }

    /**
     * An invalid {@code status} value is a type mismatch rendered as the enveloped
     * {@code 400 VALIDATION_ERROR}.
     */
    @Test
    void listWithInvalidStatusReturns400() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders?status=NOT_A_STATUS")
                        .header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));
    }

    /**
     * {@code GET /admin/orders} with a CUSTOMER token is denied {@code 403}.
     */
    @Test
    void listAsCustomerReturns403() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));
    }

    /**
     * {@code GET /admin/orders} without a token is {@code 401}.
     */
    @Test
    void listUnauthenticatedReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
    }

    /**
     * {@code GET /admin/orders/{id}} with an ADMIN token returns {@code 200} and the detail, carrying
     * the owning customer's identity — a customer other than the caller (there is no caller-ownership
     * concept on this path).
     */
    @Test
    void detailAsAdminReturns200WithCustomerIdentity() throws Exception {
        when(orderService.adminGetOrder(9L)).thenReturn(detail());

        mockMvc.perform(get("/api/v1/admin/orders/9").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.id").value(9))
                .andExpect(jsonPath("$.data.customerId").value(999))
                .andExpect(jsonPath("$.data.customerFullName").value("Someone Else"))
                .andExpect(jsonPath("$.data.customerPhone").value("0900000099"))
                .andExpect(jsonPath("$.data.shippingRecipientName").value("Jane"))
                .andExpect(jsonPath("$.data.items[0].color").value("Black"));
    }

    /**
     * {@code GET /admin/orders/{id}} with a CUSTOMER token is denied {@code 403}.
     */
    @Test
    void detailAsCustomerReturns403() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders/9").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));
    }

    /**
     * {@code GET /admin/orders/{id}} without a token is {@code 401}.
     */
    @Test
    void detailUnauthenticatedReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/admin/orders/9"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
    }

    /**
     * {@code GET /admin/orders/{id}} for a missing order reuses {@code 404 ORDER_NOT_FOUND}.
     */
    @Test
    void detailNotFoundReturns404() throws Exception {
        when(orderService.adminGetOrder(eq(9L)))
                .thenThrow(new ResourceNotFoundException("ORDER_NOT_FOUND", "Order not found"));

        mockMvc.perform(get("/api/v1/admin/orders/9").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("ORDER_NOT_FOUND"));
    }
}
