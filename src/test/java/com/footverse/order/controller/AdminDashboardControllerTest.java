package com.footverse.order.controller;

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
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.order.dto.AdminOrderSummaryResponse;
import com.footverse.order.dto.BestSellingProductResponse;
import com.footverse.order.dto.DashboardResponse;
import com.footverse.order.dto.MonthlyRevenueResponse;
import com.footverse.order.dto.OrderStatusCountResponse;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.entity.PaymentStatus;
import com.footverse.order.service.OrderService;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for {@link AdminDashboardController} (sprint-13-plan Task 01): the dashboard
 * returns {@code 200} with the assembled figures for an ADMIN, is denied {@code 403} for a CUSTOMER
 * and {@code 401} when unauthenticated, and accepts no request parameter. The security filter chain
 * is imported so authorization is exercised; the service layer is mocked.
 */
@WebMvcTest(AdminDashboardController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class AdminDashboardControllerTest {

    private static final String ADMIN_EMAIL = "dashboard-admin@example.com";
    private static final String CUSTOMER_EMAIL = "dashboard-customer@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private OrderService orderService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    AdminDashboardControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
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

    private DashboardResponse dashboard() {
        AdminOrderSummaryResponse recent = new AdminOrderSummaryResponse(5L, "FV-ORDER-5", OrderStatus.PENDING,
                PaymentStatus.UNPAID, new BigDecimal("30200.00"), 5, LocalDateTime.now(), 42L, "Jane Doe",
                "jane@example.com", "0900000001");
        return new DashboardResponse(
                new BigDecimal("500000.00"), 12, new BigDecimal("120000.00"), 8, 10,
                List.of(new OrderStatusCountResponse(OrderStatus.PENDING, 3),
                        new OrderStatusCountResponse(OrderStatus.DELIVERED, 9)),
                List.of(new MonthlyRevenueResponse(2026, 7, new BigDecimal("500000.00"), 12)),
                List.of(new BestSellingProductResponse(100L, "Air Force 1", "img.png", 10,
                        new BigDecimal("1000.00"))),
                List.of(recent));
    }

    /**
     * {@code GET /admin/dashboard} with an ADMIN token returns {@code 200} and the assembled figures.
     */
    @Test
    void getDashboardAsAdminReturns200WithFigures() throws Exception {
        when(orderService.getDashboard()).thenReturn(dashboard());

        mockMvc.perform(get("/api/v1/admin/dashboard").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.totalRevenue").value(500000.00))
                .andExpect(jsonPath("$.data.totalOrders").value(12))
                .andExpect(jsonPath("$.data.grossProfit").value(120000.00))
                .andExpect(jsonPath("$.data.profitLinesWithCost").value(8))
                .andExpect(jsonPath("$.data.profitLinesTotal").value(10))
                .andExpect(jsonPath("$.data.ordersByStatus").isArray())
                .andExpect(jsonPath("$.data.monthlyRevenue").isArray())
                .andExpect(jsonPath("$.data.bestSellingProducts[0].productId").value(100))
                .andExpect(jsonPath("$.data.recentOrders[0].orderCode").value("FV-ORDER-5"));
    }

    /**
     * {@code GET /admin/dashboard} with a CUSTOMER token is denied {@code 403}.
     */
    @Test
    void getDashboardAsCustomerReturns403() throws Exception {
        mockMvc.perform(get("/api/v1/admin/dashboard").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));
    }

    /**
     * {@code GET /admin/dashboard} without a token is {@code 401}.
     */
    @Test
    void getDashboardUnauthenticatedReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/admin/dashboard"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
    }
}
