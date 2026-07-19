package com.footverse.auth.dto;

/**
 * Result of a successful OTP verification (dto-spec §6).
 *
 * @param resetToken the opaque single-use token, consumed by {@link ResetPasswordRequest}
 * @param expiresIn  the configured reset-token TTL in seconds
 */
public record PasswordResetTokenResponse(String resetToken, Long expiresIn) {
}
