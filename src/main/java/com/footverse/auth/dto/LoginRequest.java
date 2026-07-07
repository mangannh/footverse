package com.footverse.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * Login payload for {@code POST /auth/login}. Validation follows validation-spec §3.
 *
 * @param email    required, a valid email; matched case-insensitively against the stored account
 * @param password required, matched against the stored BCrypt hash
 */
public record LoginRequest(
        @NotBlank @Email String email,
        @NotBlank String password) {
}
