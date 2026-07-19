package com.footverse.order.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.footverse.common.config.SecurityConfig;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.ResourceNotFoundException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.order.dto.VnpayReturnResponse;
import com.footverse.order.service.OrderService;

/**
 * Web-slice tests for {@link PaymentController} (sprint-13-plan Task 09): the VNPay sandbox return
 * callback is reachable with <strong>no</strong> bearer token — the gateway redirects an
 * unauthenticated browser here (security-spec §6) — and its business rejections
 * ({@code PAYMENT_SIGNATURE_INVALID}, {@code PAYMENT_TRANSACTION_NOT_FOUND},
 * {@code PAYMENT_AMOUNT_MISMATCH}) render through the standard envelope. The security filter chain is
 * imported so the {@code permitAll} rule is exercised; the service layer is mocked.
 */
@WebMvcTest(PaymentController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class PaymentControllerTest {

    private final MockMvc mockMvc;

    @MockitoBean
    private OrderService orderService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    PaymentControllerTest(@Autowired MockMvc mockMvc) {
        this.mockMvc = mockMvc;
    }

    /**
     * {@code GET /payments/vnpay/return} is reachable with no bearer token — the endpoint is
     * {@code permitAll} because the gateway itself, not a signed-in browser, redirects here.
     */
    @Test
    void handleReturnAnonymouslyReturns200() throws Exception {
        when(orderService.handleVnpayReturn(any()))
                .thenReturn(new VnpayReturnResponse(9L, "FV-ORDER-9", true, "00", "Payment successful"));

        mockMvc.perform(get("/api/v1/payments/vnpay/return")
                        .param("vnp_TxnRef", "VNP-9")
                        .param("vnp_Amount", "38000000")
                        .param("vnp_ResponseCode", "00")
                        .param("vnp_SecureHash", "deadbeef"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.orderId").value(9))
                .andExpect(jsonPath("$.data.orderCode").value("FV-ORDER-9"))
                .andExpect(jsonPath("$.data.success").value(true));
    }

    /**
     * A tampered or missing signature surfaces the service's {@code 400 PAYMENT_SIGNATURE_INVALID}
     * through the standard envelope, anonymously.
     */
    @Test
    void handleReturnWithInvalidSignatureReturns400() throws Exception {
        when(orderService.handleVnpayReturn(any())).thenThrow(new BusinessException(
                HttpStatus.BAD_REQUEST, "PAYMENT_SIGNATURE_INVALID", "Payment signature is invalid"));

        mockMvc.perform(get("/api/v1/payments/vnpay/return").param("vnp_TxnRef", "VNP-9"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("PAYMENT_SIGNATURE_INVALID"));
    }

    /**
     * An unknown {@code vnp_TxnRef} surfaces the service's {@code 404 PAYMENT_TRANSACTION_NOT_FOUND}.
     */
    @Test
    void handleReturnWithUnknownTxnRefReturns404() throws Exception {
        when(orderService.handleVnpayReturn(any())).thenThrow(new ResourceNotFoundException(
                "PAYMENT_TRANSACTION_NOT_FOUND", "Payment transaction not found"));

        mockMvc.perform(get("/api/v1/payments/vnpay/return").param("vnp_TxnRef", "VNP-UNKNOWN"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("PAYMENT_TRANSACTION_NOT_FOUND"));
    }

    /**
     * A returned amount that does not match the stored transaction surfaces the service's
     * {@code 400 PAYMENT_AMOUNT_MISMATCH}.
     */
    @Test
    void handleReturnWithAmountMismatchReturns400() throws Exception {
        when(orderService.handleVnpayReturn(any())).thenThrow(new BusinessException(
                HttpStatus.BAD_REQUEST, "PAYMENT_AMOUNT_MISMATCH", "Payment amount does not match the order"));

        mockMvc.perform(get("/api/v1/payments/vnpay/return").param("vnp_TxnRef", "VNP-9"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("PAYMENT_AMOUNT_MISMATCH"));
    }
}
