package com.footverse.order.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.common.dto.ApiResponse;
import com.footverse.order.dto.OrderDetailResponse;
import com.footverse.order.dto.PlaceOrderRequest;
import com.footverse.order.service.OrderService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Order endpoints for the authenticated customer (dto-spec §20). This task delivers checkout
 * ({@code POST /orders}); the order queries, cancellation, and admin status update are added by
 * later tasks. The controller only maps HTTP to the {@link OrderService} and wraps results in the
 * response envelope — it holds no business logic, computes no money, and performs no ownership check.
 * Role authorization is enforced by the security filter chain (security-spec §6 — every order path
 * requires CUSTOMER) and ownership by the service (security-spec §7); no endpoint accepts a user id,
 * so the caller can only ever reach their own resources.
 *
 * <p>The Swagger annotation {@code io.swagger.v3.oas.annotations.responses.ApiResponse} is written
 * fully qualified throughout, because its simple name collides with the project's response envelope
 * {@link ApiResponse} that every method returns. Error responses declare the envelope explicitly,
 * since the {@code GlobalExceptionHandler} returns it rather than the success payload
 * (error-spec §2). A {@code 403} has two distinct causes: the role denial {@code FORBIDDEN}, and the
 * ownership denials {@code CART_ITEM_FORBIDDEN} / {@code ADDRESS_FORBIDDEN} (error-spec §8.8/§8.9).</p>
 */
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    /**
     * Places an order from the caller's selected cart items (partial checkout). Customer only;
     * transactional — snapshots, stock decrement, coupon consumption, and cart-line removal commit or
     * roll back together.
     *
     * @param request the validated checkout payload
     * @return {@code 201 Created} with the created order and its checkout snapshots
     */
    @Operation(summary = "Place an order from the current customer's selected cart items")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201",
                    description = "The created order with its checkout snapshots"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation (empty, non-positive, or "
                            + "duplicate cart item ids; missing address id) or the body is malformed; "
                            + "PRODUCT_VARIANT_INACTIVE / PRODUCT_VARIANT_INSUFFICIENT_STOCK - a variant is not "
                            + "purchasable; COUPON_DISABLED / COUPON_EXPIRED / COUPON_USAGE_LIMIT_EXCEEDED / "
                            + "COUPON_MIN_ORDER_AMOUNT_NOT_MET - the coupon is not applicable",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401",
                    description = "UNAUTHORIZED - missing, invalid, or expired access token",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403",
                    description = "FORBIDDEN - the caller is not a CUSTOMER; CART_ITEM_FORBIDDEN - a cart item "
                            + "belongs to another user; ADDRESS_FORBIDDEN - the address belongs to another user",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404",
                    description = "CART_ITEM_NOT_FOUND - a cart item does not exist; ADDRESS_NOT_FOUND - the "
                            + "address does not exist; PRODUCT_VARIANT_NOT_FOUND - a variant does not exist; "
                            + "COUPON_NOT_FOUND - the coupon code does not exist",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping
    public ResponseEntity<ApiResponse<OrderDetailResponse>> placeOrder(
            @Valid @RequestBody PlaceOrderRequest request) {
        OrderDetailResponse response = orderService.placeOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }
}
