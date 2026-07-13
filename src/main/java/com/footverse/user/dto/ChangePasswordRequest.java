package com.footverse.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Payload for {@code PATCH /users/me/password}. Validation follows validation-spec §4. The caller
 * re-authenticates with {@code currentPassword}, which is verified against the stored BCrypt hash by
 * the service (a business rule, not a Bean Validation constraint). The new password is subject to the
 * same shape rule as registration (min 8 chars, at least one letter and one digit). No frozen rule
 * forbids a new password equal to the current one, so none is invented here.
 *
 * @param currentPassword required, the caller's current password (re-authentication)
 * @param newPassword     required, at least 8 characters with a letter and a digit
 */
public record ChangePasswordRequest(
        @NotBlank String currentPassword,
        @NotBlank @Size(min = 8) @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$") String newPassword) {
}
