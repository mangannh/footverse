package com.footverse.order.controller;

import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.common.dto.ApiResponse;
import com.footverse.common.dto.PageResponse;
import com.footverse.order.dto.AdminOrderDetailResponse;
import com.footverse.order.dto.AdminOrderSummaryResponse;
import com.footverse.order.entity.OrderStatus;
import com.footverse.order.service.OrderService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import lombok.RequiredArgsConstructor;

/**
 * ADMIN order read endpoints (dto-spec §20, sprint-12-plan Task 01): the management list and detail
 * that carry the owning customer's account identity the customer-scoped {@link OrderController}
 * deliberately omits. Kept separate from {@link OrderController} so the customer order contract is
 * never touched. The controller only delegates to {@link OrderService}; it holds no business logic
 * and never catches exceptions. Role authorization ({@code ROLE_ADMIN}) is enforced by the security
 * filter chain (security-spec §6); ownership is bypassed by design (security-spec §7) — every order
 * is reachable regardless of owner.
 *
 * <p>The Swagger annotation {@code io.swagger.v3.oas.annotations.responses.ApiResponse} is written
 * fully qualified throughout, because its simple name collides with the project's response envelope
 * {@link ApiResponse} that every method returns.</p>
 */
@RestController
@RequestMapping("/api/v1/admin/orders")
@RequiredArgsConstructor
public class AdminOrderController {

    private final OrderService orderService;

    /**
     * Returns a page of orders for ADMIN management, most-recent-first, each as an
     * {@link AdminOrderSummaryResponse}. Admin only.
     *
     * @param status    the optional status filter
     * @param orderCode the optional order-code search fragment (contains match)
     * @param pageable  the pagination request (default page 0, size 20)
     * @return {@code 200 OK} with the page of ADMIN order summaries
     */
    @Operation(summary = "List orders for admin management, optionally filtered by status and searched by order code")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The page of admin order summaries, most-recent-first"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - status is not a valid OrderStatus",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401",
                    description = "UNAUTHORIZED - missing, invalid, or expired access token",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403",
                    description = "FORBIDDEN - the caller is not an ADMIN",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<AdminOrderSummaryResponse>>> getOrders(
            @RequestParam(required = false) OrderStatus status,
            @RequestParam(required = false) String orderCode,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(orderService.adminListOrders(status, orderCode, pageable)));
    }

    /**
     * Returns the full ADMIN detail of an order, regardless of owner. Admin only.
     *
     * @param id the order id
     * @return {@code 200 OK} with the ADMIN order detail
     */
    @Operation(summary = "Get admin order detail, regardless of owner")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The admin order detail, carrying the owning customer's identity"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - id is not a valid number",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401",
                    description = "UNAUTHORIZED - missing, invalid, or expired access token",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403",
                    description = "FORBIDDEN - the caller is not an ADMIN",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404",
                    description = "ORDER_NOT_FOUND - no order has this id",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<AdminOrderDetailResponse>> getOrder(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.ok(orderService.adminGetOrder(id)));
    }
}
