package com.footverse.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Registration payload for {@code POST /auth/register}. Validation follows validation-spec §3.
 *
 * @param email    required, a valid email (normalized lowercase, must be unique)
 * @param password required, at least 8 characters with a letter and a digit
 * @param fullName required, the customer's full name
 * @param phone    required, Vietnamese format (10 digits, starts with 0), must be unique
 */
public record RegisterRequest(
        @NotBlank @Email String email,
        @NotBlank @Size(min = 8) @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$") String password,
        @NotBlank String fullName,
        @NotBlank @Pattern(regexp = "^0\\d{9}$") String phone) {
}
