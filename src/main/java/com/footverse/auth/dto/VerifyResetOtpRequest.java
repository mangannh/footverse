package com.footverse.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * Verifies an emailed one-time code and requests a short-lived reset token (dto-spec §6).
 *
 * @param email the account's email the code was issued to
 * @param otp   the six-digit one-time code
 */
public record VerifyResetOtpRequest(
        @NotBlank @Email String email,
        @NotBlank @Pattern(regexp = "^\\d{6}$") String otp) {
}
