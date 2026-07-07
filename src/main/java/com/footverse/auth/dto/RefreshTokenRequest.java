package com.footverse.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Refresh payload for {@code POST /auth/refresh}. Validation follows validation-spec §3.
 *
 * @param refreshToken required, the opaque refresh token previously issued
 */
public record RefreshTokenRequest(
        @NotBlank String refreshToken) {
}
