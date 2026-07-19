package com.footverse.auth.service;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.ForgotPasswordRequest;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.PasswordResetTokenResponse;
import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.dto.ResetPasswordRequest;
import com.footverse.auth.dto.VerifyResetOtpRequest;
import com.footverse.common.exception.BusinessException;

/**
 * Authentication operations. Owns all authentication logic (architecture-spec §13), including the
 * standard four-step password-reset flow (Sprint 13 Task 05); there is no separate
 * {@code PasswordResetService}.
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

    /**
     * Requests a password-reset one-time code by email (business-rules → Authentication). Always
     * completes successfully and in the same observable shape whether or not an enabled account
     * exists for the email, so the response never reveals which; a code is generated, hashed,
     * persisted, and emailed only when a matching enabled account is found.
     *
     * @param request the validated forgot-password payload
     */
    void forgotPassword(ForgotPasswordRequest request);

    /**
     * Verifies an emailed one-time code and exchanges it for a short-lived opaque reset token.
     *
     * @param request the validated verification payload
     * @return the issued reset token and its TTL
     * @throws BusinessException {@code 400 PASSWORD_RESET_OTP_INVALID} when no reset attempt exists
     *         for the email, the code does not match (attempts remain), or the attempt limit was
     *         just reached
     * @throws BusinessException {@code 400 PASSWORD_RESET_OTP_EXPIRED} when the attempt exists but
     *         has expired
     */
    PasswordResetTokenResponse verifyResetOtp(VerifyResetOtpRequest request);

    /**
     * Sets a new password using a verified reset token and revokes every refresh token the account
     * holds, ending every existing session.
     *
     * @param request the validated reset payload
     * @throws BusinessException {@code 400 PASSWORD_RESET_TOKEN_INVALID} when the token is unknown
     *         or was never verified
     * @throws BusinessException {@code 400 PASSWORD_RESET_TOKEN_EXPIRED} when the token has expired
     */
    void resetPassword(ResetPasswordRequest request);
}
