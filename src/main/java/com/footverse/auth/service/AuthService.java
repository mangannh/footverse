package com.footverse.auth.service;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.RegisterRequest;

/**
 * Authentication operations. Owns all authentication logic (architecture-spec §13); this
 * sprint task implements registration and login.
 */
public interface AuthService {

    /**
     * Registers a new customer account and issues an initial token pair.
     *
     * @param request the registration payload
     * @return the issued tokens and the new user's profile
     */
    AuthResponse register(RegisterRequest request);

    /**
     * Authenticates a user by email and password and issues a new token pair. Every login
     * inserts a new refresh-token row (multi-device) and never overwrites existing ones.
     *
     * @param request the login payload
     * @return the issued tokens and the authenticated user's profile
     */
    AuthResponse login(LoginRequest request);
}
