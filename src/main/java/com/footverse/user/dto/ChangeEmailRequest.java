package com.footverse.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * Payload for {@code PATCH /users/me/email}. Validation follows validation-spec §4. The caller
 * re-authenticates with {@code currentPassword}, verified against the stored BCrypt hash by the
 * service. The new email is normalized lowercase and must not belong to another account; submitting
 * the caller's own current email is not a conflict but an idempotent no-op (both are service-level
 * business rules, not Bean Validation constraints).
 *
 * @param newEmail        required, a valid email (normalized lowercase, unique across other accounts)
 * @param currentPassword required, the caller's current password (re-authentication)
 */
public record ChangeEmailRequest(
        @NotBlank @Email String newEmail,
        @NotBlank String currentPassword) {
}
