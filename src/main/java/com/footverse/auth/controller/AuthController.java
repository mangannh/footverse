package com.footverse.auth.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.service.AuthService;
import com.footverse.common.dto.ApiResponse;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

/**
 * Authentication endpoints. This sprint task exposes registration, login, refresh, and logout.
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
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request);
        return ResponseEntity.ok(ApiResponse.<Void>ok(null));
    }
}
