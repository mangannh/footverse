package com.footverse.user.dto;

import java.time.LocalDateTime;

import com.footverse.user.entity.Role;

/**
 * A user's profile returned to clients. Passwords are never included.
 *
 * @param id        the user id
 * @param email     the email
 * @param fullName  the full name
 * @param phone     the phone number
 * @param avatarUrl the avatar URL, if any
 * @param role      the account role
 * @param enabled   whether the account is enabled
 * @param createdAt the creation timestamp
 * @param updatedAt the last-update timestamp
 */
public record UserResponse(
        Long id,
        String email,
        String fullName,
        String phone,
        String avatarUrl,
        Role role,
        boolean enabled,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {
}
