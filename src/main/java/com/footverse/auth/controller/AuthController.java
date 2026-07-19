package com.footverse.auth.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.ForgotPasswordRequest;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.PasswordResetTokenResponse;
import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.dto.ResetPasswordRequest;
import com.footverse.auth.dto.VerifyResetOtpRequest;
import com.footverse.auth.service.AuthService;
import com.footverse.common.dto.ApiResponse;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Authentication endpoints. This sprint task exposes registration, login, refresh, logout, and the
 * three-step password-reset flow (Sprint 13 Task 05).
 *
 * <p>The Swagger annotation {@code io.swagger.v3.oas.annotations.responses.ApiResponse} is written
 * fully qualified throughout, because its simple name collides with the project's response envelope
 * {@link ApiResponse} that every method returns. Error responses declare the envelope explicitly,
 * since the {@code GlobalExceptionHandler} returns it rather than the success payload
 * (error-spec §2).</p>
 *
 * <p>Register, login, and refresh are anonymous (security-spec §6), so they never emit the
 * {@code 401 UNAUTHORIZED} of the authentication entry point; the {@code 401}s they do declare are
 * the business codes of error-spec §8.2. Logout is authenticated and additionally enforces
 * ownership of the presented refresh token. Forgot-password, verify-reset-otp, and reset-password
 * are anonymous as well; their rejections are the {@code 400} business codes of error-spec §8.14,
 * never a {@code 401} or {@code 404}, so the flow never reveals whether an email is registered.</p>
 */
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /**
     * Registers a new customer account.
     *
     * @param request the validated registration payload
     * @return {@code 201 Created} with the issued tokens and the new user's profile
     */
    @Operation(summary = "Register a new customer account")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201",
                    description = "The account was created; the issued token pair and profile are returned"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation, or the body is malformed",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409",
                    description = "USER_EMAIL_DUPLICATED or USER_PHONE_DUPLICATED - already registered",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthResponse>> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.created(response));
    }

    /**
     * Authenticates a user and issues a new token pair.
     *
     * @param request the validated login payload
     * @return {@code 200 OK} with the issued tokens and the authenticated user's profile
     */
    @Operation(summary = "Authenticate and obtain a JWT token pair")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The issued token pair and the authenticated user's profile"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation, or the body is malformed",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401",
                    description = "INVALID_CREDENTIALS - wrong email or password; "
                            + "ACCOUNT_DISABLED - the account is disabled",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * Rotates a refresh token for a new token pair (single-use rotation).
     *
     * @param request the validated refresh payload
     * @return {@code 200 OK} with the newly issued tokens and the owner's profile
     */
    @Operation(summary = "Rotate a refresh token for a new JWT token pair")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The newly issued token pair and the owner's profile"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - refreshToken is missing, or the body is malformed",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401",
                    description = "REFRESH_TOKEN_INVALID - unknown or already rotated token; "
                            + "REFRESH_TOKEN_EXPIRED - the token has expired; "
                            + "ACCOUNT_DISABLED - the owning account is disabled",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        AuthResponse response = authService.refresh(request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * Revokes the presented refresh token for the authenticated caller (idempotent logout).
     *
     * @param request the validated payload carrying the refresh token to revoke
     * @return {@code 200 OK} with an empty envelope
     */
    @Operation(summary = "Revoke the presented refresh token (authenticated logout)")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The token was revoked, or it was unknown or already revoked (idempotent)"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - refreshToken is missing, or the body is malformed",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401",
                    description = "UNAUTHORIZED - missing, invalid, or expired access token",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403",
                    description = "REFRESH_TOKEN_FORBIDDEN - the refresh token belongs to another user",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null));
    }

    /**
     * Requests a password-reset one-time code by email. Always answers {@code 200} with an empty
     * envelope, whether or not the email belongs to an enabled account (non-enumeration).
     *
     * @param request the validated forgot-password payload
     * @return {@code 200 OK} with an empty envelope
     */
    @Operation(summary = "Request a password-reset one-time code by email")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "Always returned, whether or not the email belongs to an enabled account"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - email is missing or malformed, or the body is malformed",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @PostMapping("/forgot-password")
    public ResponseEntity<ApiResponse<Void>> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null));
    }

    /**
     * Verifies an emailed one-time code and issues a short-lived opaque reset token.
     *
     * @param request the validated verification payload
     * @return {@code 200 OK} with the issued reset token and its TTL
     */
    @Operation(summary = "Verify a password-reset one-time code and obtain a reset token")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The issued opaque reset token and its TTL"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation, or the body is malformed; "
                            + "PASSWORD_RESET_OTP_INVALID - no attempt exists, or the code is wrong; "
                            + "PASSWORD_RESET_OTP_EXPIRED - the code has expired",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @PostMapping("/verify-reset-otp")
    public ResponseEntity<ApiResponse<PasswordResetTokenResponse>> verifyResetOtp(
            @Valid @RequestBody VerifyResetOtpRequest request) {
        PasswordResetTokenResponse response = authService.verifyResetOtp(request);
        return ResponseEntity.ok(ApiResponse.ok(response));
    }

    /**
     * Sets a new password using a verified reset token and revokes every refresh token the account
     * holds.
     *
     * @param request the validated reset payload
     * @return {@code 200 OK} with an empty envelope
     */
    @Operation(summary = "Set a new password using a verified reset token")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200",
                    description = "The password was reset and every refresh token for the account was revoked"),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400",
                    description = "VALIDATION_ERROR - a field failed validation, or the body is malformed; "
                            + "PASSWORD_RESET_TOKEN_INVALID - the token is unknown or was never verified; "
                            + "PASSWORD_RESET_TOKEN_EXPIRED - the token has expired",
                    content = @Content(mediaType = "application/json",
                            schema = @Schema(implementation = ApiResponse.class)))
    })
    @PostMapping("/reset-password")
    public ResponseEntity<ApiResponse<Void>> resetPassword(@Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null));
    }
}
