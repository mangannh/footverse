package com.footverse.order.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.common.dto.ApiResponse;
import com.footverse.order.dto.DashboardResponse;
import com.footverse.order.service.OrderService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import lombok.RequiredArgsConstructor;

/**
 * The ADMIN dashboard read endpoint (dto-spec §20, sprint-13-plan Task 01): the store's core
 * operating figures, assembled from {@code orders} / {@code order_item} aggregates. Kept separate
 * from {@link AdminOrderController} purely to keep the HTTP surfaces cleanly split (sprint-12-plan
 * Design Decision 3), exactly as {@link AdminOrderController} is separate from the customer
 * {@link OrderController}. The controller only delegates to {@link OrderService}; it holds no
 * business logic and never catches exceptions. Role authorization ({@code ROLE_ADMIN}) is enforced by
 * the security filter chain (security-spec §6); the endpoint takes no request parameters — every
 * window is fixed (sprint-13-plan Task 01 Design Notes).
 *
 * <p>The Swagger annotation {@code io.swagger.v3.oas.annotations.responses.ApiResponse} is written
 * fully qualified throughout, because its simple name collides with the project's response envelope
 * {@link ApiResponse} that the method returns.</p>
 */
@RestController
@RequestMapping("/api/v1/admin/dashboard")
@RequiredArgsConstructor
public class AdminDashboardController {

    private final OrderService orderService;

    /**
     * Returns the ADMIN dashboard's core operating figures. Admin only; takes no parameters.
     *
     * @return {@code 200 OK} with the assembled dashboard response
     */
    @Operation(summary = "Get the ADMIN dashboard's core operating figures")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The assembled dashboard response"),
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
    public ResponseEntity<ApiResponse<DashboardResponse>> getDashboard() {
        return ResponseEntity.ok(ApiResponse.ok(orderService.getDashboard()));
    }
}
