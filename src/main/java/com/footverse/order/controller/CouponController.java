package com.footverse.order.controller;

import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.common.dto.ApiResponse;
import com.footverse.common.dto.PageResponse;
import com.footverse.order.dto.CouponPreviewRequest;
import com.footverse.order.dto.CouponPreviewResponse;
import com.footverse.order.dto.CouponResponse;
import com.footverse.order.dto.CreateCouponRequest;
import com.footverse.order.dto.UpdateCouponRequest;
import com.footverse.order.service.OrderService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Coupon endpoints (dto-spec §20): the admin listing / create / update, plus the CUSTOMER checkout
 * preview {@code POST /coupons/validate}. The controller only maps HTTP to the {@link OrderService}
 * and wraps results in the response envelope — it holds no business logic and never catches
 * exceptions. Role authorization is enforced by the security filter chain (security-spec §6 — the
 * admin operations require ADMIN, the preview requires CUSTOMER), so each operation carries only the
 * Swagger security requirement here; none of these endpoints is public, so all declare {@code 401}
 * and {@code 403}.
 *
 * <p>The Swagger annotation {@code io.swagger.v3.oas.annotations.responses.ApiResponse} is written
 * fully qualified throughout, because its simple name collides with the project's response envelope
 * {@link ApiResponse} that every method returns. Error responses declare the envelope explicitly,
 * since the {@code GlobalExceptionHandler} returns it rather than the success payload
 * (error-spec §2).</p>
 */
@RestController
@RequestMapping("/api/v1/coupons")
@RequiredArgsConstructor
public class CouponController {

    private final OrderService orderService;

    /**
     * Previews the checkout summary for the caller's selected cart items, optionally applying a
     * coupon. Customer only; read-only (mutates nothing).
     *
     * @param request the validated preview payload (selected cart item ids and optional coupon code)
     * @return {@code 200 OK} with the server-computed checkout summary
     */
    @Operation(summary = "Preview a checkout summary, optionally applying a coupon")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The server-computed checkout summary"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation (empty, non-positive, or "
                            + "duplicate cart item ids) or the body is malformed; COUPON_DISABLED / COUPON_EXPIRED / "
                            + "COUPON_USAGE_LIMIT_EXCEEDED / COUPON_MIN_ORDER_AMOUNT_NOT_MET - the coupon is not "
                            + "applicable",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401",
                    description = "UNAUTHORIZED - missing, invalid, or expired access token",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403",
                    description = "FORBIDDEN - the caller is not a CUSTOMER; CART_ITEM_FORBIDDEN - a cart item "
                            + "belongs to another user",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404",
                    description = "CART_ITEM_NOT_FOUND - a cart item does not exist; COUPON_NOT_FOUND - the "
                            + "coupon code does not exist",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/validate")
    public ResponseEntity<ApiResponse<CouponPreviewResponse>> validateCoupon(
            @Valid @RequestBody CouponPreviewRequest request) {
        return ResponseEntity.ok(ApiResponse.ok(orderService.previewCoupon(request)));
    }

    /**
     * Lists coupons, paginated. Admin only.
     *
     * @param pageable the pagination and sort request (default page 0, size 20)
     * @return {@code 200 OK} with the page of coupons
     */
    @Operation(summary = "List coupons")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The page of coupons"),
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
    public ResponseEntity<ApiResponse<PageResponse<CouponResponse>>> getCoupons(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.ok(orderService.getCoupons(pageable)));
    }

    /**
     * Creates a new coupon. Admin only.
     *
     * @param request the validated create payload
     * @return {@code 201 Created} with the created coupon
     */
    @Operation(summary = "Create a new coupon")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201",
                    description = "The created coupon"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation, or the body is malformed; "
                            + "COUPON_INVALID_DATE_RANGE - endAt is not after startAt",
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
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409",
                    description = "COUPON_CODE_DUPLICATED - the code is already taken",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping
    public ResponseEntity<ApiResponse<CouponResponse>> createCoupon(
            @Valid @RequestBody CreateCouponRequest request) {
        CouponResponse response = orderService.createCoupon(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    /**
     * Updates an existing coupon. Admin only.
     *
     * @param id      the id of the coupon to update
     * @param request the validated update payload
     * @return {@code 200 OK} with the updated coupon
     */
    @Operation(summary = "Update an existing coupon")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The updated coupon"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation, the body is malformed, "
                            + "or id is not a valid number; COUPON_INVALID_DATE_RANGE - endAt is not after startAt",
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
                    description = "COUPON_NOT_FOUND - no coupon has this id",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409",
                    description = "COUPON_CODE_DUPLICATED - the code is already taken",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @SecurityRequirement(name = "bearerAuth")
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<CouponResponse>> updateCoupon(
            @PathVariable Long id,
            @Valid @RequestBody UpdateCouponRequest request) {
        CouponResponse response = orderService.updateCoupon(id, request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }
}
