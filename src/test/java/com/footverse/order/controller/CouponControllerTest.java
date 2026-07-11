package com.footverse.order.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.footverse.common.config.SecurityConfig;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.ResourceNotFoundException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.order.dto.CouponPreviewResponse;
import com.footverse.order.service.OrderService;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for the {@link CouponController} CUSTOMER checkout preview
 * {@code POST /coupons/validate}: the success envelope, the request-body validation (empty and
 * duplicate cart item ids), the role denial for an ADMIN token, the anonymous {@code 401}, and the
 * coupon / cart business errors rendered through the standard envelope. The security filter chain is
 * imported; the service is mocked, so no business rule runs here.
 */
@WebMvcTest(CouponController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class CouponControllerTest {

    private static final String CUSTOMER_EMAIL = "customer@example.com";
    private static final String ADMIN_EMAIL = "admin@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private OrderService orderService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    CouponControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
    }

    private String customerToken() {
        when(userDetailsService.loadUserByUsername(CUSTOMER_EMAIL))
                .thenReturn(AuthFixtures.userDetails(CUSTOMER_EMAIL, Role.CUSTOMER));
        return "Bearer " + jwtUtil.createAccessToken(CUSTOMER_EMAIL);
    }

    private String adminToken() {
        when(userDetailsService.loadUserByUsername(ADMIN_EMAIL))
                .thenReturn(AuthFixtures.userDetails(ADMIN_EMAIL, Role.ADMIN));
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private CouponPreviewResponse previewWithCoupon() {
        return new CouponPreviewResponse("SAVE", "Save Now", new BigDecimal("200.00"),
                new BigDecimal("20.00"), new BigDecimal("30000.00"), new BigDecimal("30180.00"));
    }

    /**
     * {@code POST /coupons/validate} as a CUSTOMER returns the server-computed checkout summary.
     */
    @Test
    void validateAsCustomerReturns200() throws Exception {
        when(orderService.previewCoupon(any())).thenReturn(previewWithCoupon());

        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"SAVE\",\"cartItemIds\":[10,11]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("OK"))
                .andExpect(jsonPath("$.data.code").value("SAVE"))
                .andExpect(jsonPath("$.data.subtotal").value(200.00))
                .andExpect(jsonPath("$.data.discountAmount").value(20.00))
                .andExpect(jsonPath("$.data.shippingFee").value(30000.00))
                .andExpect(jsonPath("$.data.total").value(30180.00));
    }

    /**
     * A preview without a coupon code is accepted: the code is optional.
     */
    @Test
    void validateWithoutCouponCodeReturns200() throws Exception {
        when(orderService.previewCoupon(any())).thenReturn(new CouponPreviewResponse(null, null,
                new BigDecimal("200.00"), BigDecimal.ZERO, new BigDecimal("30000.00"), new BigDecimal("30200.00")));

        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"cartItemIds\":[10]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.code").doesNotExist())
                .andExpect(jsonPath("$.data.discountAmount").value(0))
                .andExpect(jsonPath("$.data.total").value(30200.00));
    }

    /**
     * An empty {@code cartItemIds} fails Bean Validation with the enveloped {@code 400}
     * (validation-spec §9): a preview must select at least one line.
     */
    @Test
    void validateWithEmptyCartItemIdsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"SAVE\",\"cartItemIds\":[]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[0].field").value("cartItemIds"));

        verify(orderService, never()).previewCoupon(any());
    }

    /**
     * Duplicate cart item ids fail Bean Validation ({@code @UniqueElements}) with the enveloped
     * {@code 400} (validation-spec §9).
     */
    @Test
    void validateWithDuplicateCartItemIdsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"SAVE\",\"cartItemIds\":[10,10]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[0].field").value("cartItemIds"));

        verify(orderService, never()).previewCoupon(any());
    }

    /**
     * A non-positive cart item id fails Bean Validation ({@code @Positive} on the elements).
     */
    @Test
    void validateWithNonPositiveCartItemIdReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"SAVE\",\"cartItemIds\":[0]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(orderService, never()).previewCoupon(any());
    }

    /**
     * {@code POST /coupons/validate} with an ADMIN token is denied the enveloped {@code 403}: the
     * preview is CUSTOMER-only (security-spec §6).
     */
    @Test
    void validateAsAdminReturns403() throws Exception {
        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"SAVE\",\"cartItemIds\":[10]}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        verify(orderService, never()).previewCoupon(any());
    }

    /**
     * An anonymous request is denied the enveloped {@code 401} (security-spec §6).
     */
    @Test
    void validateAnonymouslyReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/coupons/validate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"SAVE\",\"cartItemIds\":[10]}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(orderService, never()).previewCoupon(any());
    }

    /**
     * A coupon that is not applicable surfaces the service's {@code 400 COUPON_EXPIRED} through the
     * standard envelope.
     */
    @Test
    void validateWithExpiredCouponReturns400() throws Exception {
        when(orderService.previewCoupon(any()))
                .thenThrow(new BusinessException(HttpStatus.BAD_REQUEST, "COUPON_EXPIRED",
                        "Coupon is not valid at this time"));

        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"SAVE\",\"cartItemIds\":[10]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("COUPON_EXPIRED"));
    }

    /**
     * An unknown coupon code surfaces the service's {@code 404 COUPON_NOT_FOUND}.
     */
    @Test
    void validateWithUnknownCouponReturns404() throws Exception {
        when(orderService.previewCoupon(any()))
                .thenThrow(new ResourceNotFoundException("COUPON_NOT_FOUND", "Coupon not found"));

        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"NOPE\",\"cartItemIds\":[10]}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("COUPON_NOT_FOUND"));
    }

    /**
     * A cart item that belongs to another user surfaces the service's {@code 403 CART_ITEM_FORBIDDEN}.
     */
    @Test
    void validateWithForeignCartItemReturns403() throws Exception {
        when(orderService.previewCoupon(any()))
                .thenThrow(new BusinessException(HttpStatus.FORBIDDEN, "CART_ITEM_FORBIDDEN",
                        "You cannot access this cart item"));

        mockMvc.perform(post("/api/v1/coupons/validate")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"cartItemIds\":[10]}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("CART_ITEM_FORBIDDEN"));
    }
}
