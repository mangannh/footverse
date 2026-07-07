package com.footverse.auth.service;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.dto.RegisterRequest;

/**
 * Authentication operations. Owns all authentication logic (architecture-spec §13); this
 * sprint task implements registration, login, refresh-token rotation, and logout.
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

    /**
     * Rotates a refresh token following the canonical single-use flow (security-spec §2): the
     * presented token is validated, its row deleted, and a new access/refresh pair issued. An
     * unknown, expired, or already-rotated token is rejected with an enveloped 401.
     *
     * @param request the refresh payload carrying the opaque refresh token
     * @return the newly issued tokens and the owner's profile
     */
    AuthResponse refresh(RefreshTokenRequest request);

    /**
     * Revokes the presented refresh token on behalf of the authenticated caller (security-spec
     * §1). The token is deleted only after verifying it belongs to the current user; a token
     * owned by another user is rejected with 403. The operation is intentionally idempotent — an
     * unknown or already-revoked token is a no-op — so it never leaks whether a token exists.
     * Only the presented token is revoked; the caller's other devices are unaffected.
     *
     * @param request the payload carrying the opaque refresh token to revoke
     */
    void logout(RefreshTokenRequest request);
}
