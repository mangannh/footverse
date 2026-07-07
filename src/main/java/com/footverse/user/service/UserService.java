package com.footverse.user.service;

import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.User;

/**
 * User-module façade for the operations other features need. It is the only entry point into
 * user data for cross-feature callers (architecture-spec §6/§7). Only the methods required by
 * registration are exposed in this sprint.
 */
public interface UserService {

    /**
     * Checks whether an account with the given email already exists.
     *
     * @param email the email to check
     * @return {@code true} if the email is taken
     */
    boolean existsByEmail(String email);

    /**
     * Checks whether an account with the given phone already exists.
     *
     * @param phone the phone to check
     * @return {@code true} if the phone is taken
     */
    boolean existsByPhone(String phone);

    /**
     * Creates and persists a new customer account with the given already-encoded password.
     *
     * @param email           the normalized email
     * @param encodedPassword the BCrypt-encoded password
     * @param fullName        the full name
     * @param phone           the phone number
     * @return the persisted user
     */
    User createUser(String email, String encodedPassword, String fullName, String phone);

    /**
     * Maps a user to its response DTO.
     *
     * @param user the user
     * @return the response DTO
     */
    UserResponse toResponse(User user);
}
