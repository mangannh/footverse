package com.footverse.auth.dto;

import com.footverse.user.dto.UserResponse;

/**
 * Result of a successful register / login / refresh.
 *
 * @param accessToken  the stateless JWT access token (expires in 15 minutes)
 * @param refreshToken the opaque refresh token (raw value; only its hash is stored server-side)
 * @param expiresIn    the configured access-token TTL in seconds
 * @param tokenType    the fixed value {@code "Bearer"}
 * @param user         the authenticated user's profile
 */
public record AuthResponse(
        String accessToken,
        String refreshToken,
        Long expiresIn,
        String tokenType,
        UserResponse user) {
}
