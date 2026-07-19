package com.footverse.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Sets a new password using a verified reset token (dto-spec §6). Revokes every refresh token the
 * account holds.
 *
 * @param resetToken  the opaque token returned by verifying a {@link VerifyResetOtpRequest}
 * @param newPassword the new password; the same rule as {@code RegisterRequest.password} /
 *                    {@code ChangePasswordRequest.newPassword} (min 8 characters, at least one
 *                    letter and one digit)
 */
public record ResetPasswordRequest(
        @NotBlank @Size(max = 128) String resetToken,
        @NotBlank @Size(min = 8) @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$") String newPassword) {
}
