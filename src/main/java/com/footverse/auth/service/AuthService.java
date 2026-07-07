package com.footverse.auth.service;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.RegisterRequest;

/**
 * Authentication operations. Owns all authentication logic (architecture-spec §13); this
 * sprint task implements registration only.
 */
public interface AuthService {

    /**
     * Registers a new customer account and issues an initial token pair.
     *
     * @param request the registration payload
     * @return the issued tokens and the new user's profile
     */
    AuthResponse register(RegisterRequest request);
}
