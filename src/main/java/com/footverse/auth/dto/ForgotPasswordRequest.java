package com.footverse.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * Requests a password-reset one-time code by email (dto-spec §6). The response is always the same
 * whether or not the email belongs to an enabled account (business-rules → Authentication).
 *
 * @param email the account's email
 */
public record ForgotPasswordRequest(
        @NotBlank @Email String email) {
}
