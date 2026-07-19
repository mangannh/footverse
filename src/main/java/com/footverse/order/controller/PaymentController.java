package com.footverse.order.controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.common.dto.ApiResponse;
import com.footverse.order.dto.VnpayReturnResponse;
import com.footverse.order.service.OrderService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import lombok.RequiredArgsConstructor;

/**
 * The VNPay sandbox return-callback endpoint (dto-spec §20, sprint-13-plan Task 09). Kept separate
 * from {@link OrderController} because its HTTP surface is fundamentally different — the gateway
 * redirects an unauthenticated browser here, so it takes no bearer token and no path-scoped resource
 * id (sprint-13-plan Design Decision 3, mirroring the {@code AdminDashboardController} /
 * {@code AdminOrderController} split). The controller only binds the {@code vnp_*} query parameters
 * and delegates to {@link OrderService#handleVnpayReturn(Map)}; it holds no business logic and never
 * inspects a parameter itself — the service verifies the signature before trusting any of them.
 *
 * <p>The Swagger annotation {@code io.swagger.v3.oas.annotations.responses.ApiResponse} is written
 * fully qualified throughout, because its simple name collides with the project's response envelope
 * {@link ApiResponse} that the method returns.</p>
 */
@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final OrderService orderService;

    /**
     * Handles the VNPay sandbox gateway's signed return redirect. Anonymous — the gateway carries no
     * bearer token (security-spec §6); the signature, not the session, is this endpoint's security.
     *
     * @param params every {@code vnp_*} query parameter the gateway attached, including
     *               {@code vnp_SecureHash}
     * @return {@code 200 OK} with the verified payment outcome
     */
    @Operation(summary = "Handle the VNPay sandbox gateway's signed return callback")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The verified payment outcome (success or failure)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "PAYMENT_SIGNATURE_INVALID - the vnp_SecureHash does not verify; "
                            + "PAYMENT_AMOUNT_MISMATCH - the returned amount does not match the stored transaction",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404",
                    description = "PAYMENT_TRANSACTION_NOT_FOUND - no transaction has this vnp_TxnRef",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @GetMapping("/vnpay/return")
    public ResponseEntity<ApiResponse<VnpayReturnResponse>> handleVnpayReturn(
            @RequestParam Map<String, String> params) {
        return ResponseEntity.ok(ApiResponse.ok(orderService.handleVnpayReturn(params)));
    }
}
