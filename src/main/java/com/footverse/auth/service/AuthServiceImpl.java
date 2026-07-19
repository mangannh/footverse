package com.footverse.auth.service;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Locale;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.ForgotPasswordRequest;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.PasswordResetTokenResponse;
import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.dto.ResetPasswordRequest;
import com.footverse.auth.dto.VerifyResetOtpRequest;
import com.footverse.auth.entity.PasswordResetToken;
import com.footverse.auth.entity.RefreshToken;
import com.footverse.auth.repository.PasswordResetTokenRepository;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.mail.EmailSender;
import com.footverse.common.security.CurrentUserProvider;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.util.TokenHasher;
import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.User;
import com.footverse.user.service.UserService;

/**
 * Default {@link AuthService} implementation. Registration validates uniqueness, creates the
 * user (through {@link UserService}), and issues an access token plus a rotating refresh token
 * whose SHA-256 hash is the only server-side copy. Login verifies the BCrypt password and the
 * {@code enabled} flag, then issues a fresh token pair — inserting a new refresh-token row on
 * every login (multi-device) without overwriting existing ones. Refresh rotates a single-use
 * token following the canonical 12-step flow (security-spec §2): the old row is deleted and a
 * new access/refresh pair issued. Logout revokes the presented refresh token after an ownership
 * check via {@link CurrentUserProvider}, and is idempotent.
 *
 * <p>The standard four-step password-reset flow (Sprint 13 Task 05) also lives here rather than in
 * a separate {@code PasswordResetService}: {@link #forgotPassword} never reveals whether an email
 * is registered, {@link #verifyResetOtp} exchanges a correct one-time code for a short-lived opaque
 * reset token, and {@link #resetPassword} consumes that token and revokes every refresh token the
 * account holds. The one {@link PasswordResetToken} row per account carries the whole attempt —
 * OTP hash, then reset-token hash — through both steps.</p>
 */
@Service
public class AuthServiceImpl implements AuthService {

    private static final int REFRESH_TOKEN_BYTES = 32;
    private static final int RESET_TOKEN_BYTES = 32;
    private static final int OTP_BOUND = 1_000_000;
    private static final String OTP_FORMAT = "%06d";
    private static final String TOKEN_TYPE = "Bearer";
    private static final String INVALID_CREDENTIALS_CODE = "INVALID_CREDENTIALS";
    private static final String INVALID_CREDENTIALS_MESSAGE = "Invalid email or password";
    private static final String ACCOUNT_DISABLED_CODE = "ACCOUNT_DISABLED";
    private static final String ACCOUNT_DISABLED_MESSAGE = "Account is disabled";
    private static final String REFRESH_TOKEN_INVALID_CODE = "REFRESH_TOKEN_INVALID";
    private static final String REFRESH_TOKEN_INVALID_MESSAGE = "Refresh token is invalid";
    private static final String REFRESH_TOKEN_EXPIRED_CODE = "REFRESH_TOKEN_EXPIRED";
    private static final String REFRESH_TOKEN_EXPIRED_MESSAGE = "Refresh token has expired";
    private static final String REFRESH_TOKEN_FORBIDDEN_CODE = "REFRESH_TOKEN_FORBIDDEN";
    private static final String REFRESH_TOKEN_FORBIDDEN_MESSAGE = "You cannot revoke this refresh token";
    private static final String PASSWORD_RESET_OTP_INVALID_CODE = "PASSWORD_RESET_OTP_INVALID";
    private static final String PASSWORD_RESET_OTP_INVALID_MESSAGE = "Reset code is invalid";
    private static final String PASSWORD_RESET_OTP_EXPIRED_CODE = "PASSWORD_RESET_OTP_EXPIRED";
    private static final String PASSWORD_RESET_OTP_EXPIRED_MESSAGE = "Reset code has expired";
    private static final String PASSWORD_RESET_TOKEN_INVALID_CODE = "PASSWORD_RESET_TOKEN_INVALID";
    private static final String PASSWORD_RESET_TOKEN_INVALID_MESSAGE = "Reset token is invalid";
    private static final String PASSWORD_RESET_TOKEN_EXPIRED_CODE = "PASSWORD_RESET_TOKEN_EXPIRED";
    private static final String PASSWORD_RESET_TOKEN_EXPIRED_MESSAGE = "Reset token has expired";
    private static final String PASSWORD_RESET_EMAIL_SUBJECT = "Your FootVerse password reset code";

    private final SecureRandom secureRandom = new SecureRandom();

    private final UserService userService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final TokenHasher tokenHasher;
    private final CurrentUserProvider currentUserProvider;
    private final EmailSender emailSender;
    private final long accessTokenTtlSeconds;
    private final long refreshTokenTtlSeconds;
    private final long otpTtlSeconds;
    private final long resetTokenTtlSeconds;
    private final int maxAttempts;

    /**
     * Creates the service.
     *
     * @param userService                  the user-module façade
     * @param refreshTokenRepository        the refresh-token store
     * @param passwordResetTokenRepository  the password-reset attempt store
     * @param passwordEncoder               the BCrypt password encoder
     * @param jwtUtil                       the access-token utility
     * @param tokenHasher                   the SHA-256 hasher for refresh and reset tokens
     * @param currentUserProvider           the authenticated-user access point (for logout ownership)
     * @param emailSender                   the outbound mail gateway for the reset code
     * @param accessTokenTtlSeconds         the access-token TTL in seconds (for {@code expiresIn})
     * @param refreshTokenTtlSeconds        the refresh-token TTL in seconds
     * @param otpTtlSeconds                 the one-time-code TTL in seconds
     * @param resetTokenTtlSeconds          the verified reset-token TTL in seconds
     * @param maxAttempts                   the number of wrong-code attempts allowed before the row
     *                                      is invalidated
     */
    public AuthServiceImpl(UserService userService,
                           RefreshTokenRepository refreshTokenRepository,
                           PasswordResetTokenRepository passwordResetTokenRepository,
                           PasswordEncoder passwordEncoder,
                           JwtUtil jwtUtil,
                           TokenHasher tokenHasher,
                           CurrentUserProvider currentUserProvider,
                           EmailSender emailSender,
                           @Value("${footverse.jwt.access-token-ttl-seconds}") long accessTokenTtlSeconds,
                           @Value("${footverse.jwt.refresh-token-ttl-seconds}") long refreshTokenTtlSeconds,
                           @Value("${footverse.password-reset.otp-ttl-seconds}") long otpTtlSeconds,
                           @Value("${footverse.password-reset.reset-token-ttl-seconds}")
                                   long resetTokenTtlSeconds,
                           @Value("${footverse.password-reset.max-attempts}") int maxAttempts) {
        this.userService = userService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.tokenHasher = tokenHasher;
        this.currentUserProvider = currentUserProvider;
        this.emailSender = emailSender;
        this.accessTokenTtlSeconds = accessTokenTtlSeconds;
        this.refreshTokenTtlSeconds = refreshTokenTtlSeconds;
        this.otpTtlSeconds = otpTtlSeconds;
        this.resetTokenTtlSeconds = resetTokenTtlSeconds;
        this.maxAttempts = maxAttempts;
    }

    @Override
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = request.email().toLowerCase(Locale.ROOT);
        if (userService.existsByEmail(email)) {
            throw new DuplicateResourceException("USER_EMAIL_DUPLICATED", "Email already exists");
        }
        if (userService.existsByPhone(request.phone())) {
            throw new DuplicateResourceException("USER_PHONE_DUPLICATED", "Phone already exists");
        }

        String encodedPassword = passwordEncoder.encode(request.password());
        User user = userService.createUser(email, encodedPassword, request.fullName(), request.phone());

        String accessToken = jwtUtil.createAccessToken(user.getEmail());
        String rawRefreshToken = issueRefreshToken(user);
        UserResponse userResponse = userService.toResponse(user);

        return new AuthResponse(accessToken, rawRefreshToken, accessTokenTtlSeconds, TOKEN_TYPE, userResponse);
    }

    @Override
    @Transactional
    public AuthResponse login(LoginRequest request) {
        String email = request.email().toLowerCase(Locale.ROOT);
        User user = userService.findByEmail(email)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED,
                        INVALID_CREDENTIALS_CODE, INVALID_CREDENTIALS_MESSAGE));
        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED,
                    INVALID_CREDENTIALS_CODE, INVALID_CREDENTIALS_MESSAGE);
        }
        if (!user.isEnabled()) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED,
                    ACCOUNT_DISABLED_CODE, ACCOUNT_DISABLED_MESSAGE);
        }

        String accessToken = jwtUtil.createAccessToken(user.getEmail());
        String rawRefreshToken = issueRefreshToken(user);
        UserResponse userResponse = userService.toResponse(user);

        return new AuthResponse(accessToken, rawRefreshToken, accessTokenTtlSeconds, TOKEN_TYPE, userResponse);
    }

    /**
     * Rotates a refresh token following the canonical 12-step flow of security-spec §2. The old
     * row is deleted (steps 5 and 7) and a new access/refresh pair is issued, so a rotated token
     * can never be reused.
     *
     * <p>{@code noRollbackFor = BusinessException.class} preserves step 5's mandated cleanup: the
     * expired row is deleted <em>and</em> a {@link BusinessException} is thrown, and without this
     * the default rollback-on-{@code RuntimeException} rule would undo that delete, leaving the
     * expired row in the database and violating the frozen lazy-cleanup rule. It is safe here
     * because the only exception path that has written anything is the expired-row deletion (which
     * must commit); the happy-path rotation never throws, and the invalid/disabled paths write
     * nothing. Genuine persistence failures do not extend {@code BusinessException}, so they still
     * roll the rotation back atomically.</p>
     */
    @Override
    @Transactional(noRollbackFor = BusinessException.class)
    public AuthResponse refresh(RefreshTokenRequest request) {
        // Steps 1-2: receive the token and hash it with SHA-256.
        String tokenHash = tokenHasher.hash(request.refreshToken());

        // Step 3: look up the row by token_hash.
        RefreshToken existing = refreshTokenRepository.findByTokenHash(tokenHash)
                // Step 4: no row exists -> 401 REFRESH_TOKEN_INVALID.
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED,
                        REFRESH_TOKEN_INVALID_CODE, REFRESH_TOKEN_INVALID_MESSAGE));

        // Step 5: expired -> delete the row and return 401 REFRESH_TOKEN_EXPIRED.
        if (existing.getExpiresAt().isBefore(LocalDateTime.now())) {
            refreshTokenRepository.delete(existing);
            throw new BusinessException(HttpStatus.UNAUTHORIZED,
                    REFRESH_TOKEN_EXPIRED_CODE, REFRESH_TOKEN_EXPIRED_MESSAGE);
        }

        // Step 6: resolve the owning user and verify the account is enabled.
        User user = existing.getUser();
        if (!user.isEnabled()) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED,
                    ACCOUNT_DISABLED_CODE, ACCOUNT_DISABLED_MESSAGE);
        }

        // Step 7: delete the old row.
        refreshTokenRepository.delete(existing);

        // Step 8: generate a new access token.
        String accessToken = jwtUtil.createAccessToken(user.getEmail());
        // Steps 9-11: generate a new refresh token, hash it, and insert the new row.
        String rawRefreshToken = issueRefreshToken(user);
        UserResponse userResponse = userService.toResponse(user);

        // Step 12: return the new AuthResponse.
        return new AuthResponse(accessToken, rawRefreshToken, accessTokenTtlSeconds, TOKEN_TYPE, userResponse);
    }

    /**
     * Revokes the presented refresh token for the authenticated caller (security-spec §1). An
     * unknown or already-revoked token is a no-op (idempotent, no existence leak); a token owned
     * by another user is rejected with 403 without being deleted; otherwise only that single row
     * is deleted, leaving the caller's other devices untouched.
     */
    @Override
    @Transactional
    public void logout(RefreshTokenRequest request) {
        String tokenHash = tokenHasher.hash(request.refreshToken());
        RefreshToken existing = refreshTokenRepository.findByTokenHash(tokenHash).orElse(null);
        if (existing == null) {
            return;
        }

        User currentUser = currentUserProvider.getCurrentUser();
        if (!existing.getUser().getId().equals(currentUser.getId())) {
            throw new BusinessException(HttpStatus.FORBIDDEN,
                    REFRESH_TOKEN_FORBIDDEN_CODE, REFRESH_TOKEN_FORBIDDEN_MESSAGE);
        }

        refreshTokenRepository.delete(existing);
    }

    /**
     * Requests a password-reset one-time code (Design Note — never reveal whether an email is
     * registered). The lookup runs first and every branch does equally little work, so neither the
     * response body nor its timing leaks whether the account exists: only a matching, enabled
     * account gets a fresh row and an email.
     */
    @Override
    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        String email = request.email().toLowerCase(Locale.ROOT);
        userService.findByEmail(email)
                .filter(User::isEnabled)
                .ifPresent(this::issuePasswordResetOtp);
    }

    private void issuePasswordResetOtp(User user) {
        passwordResetTokenRepository.deleteByUserId(user.getId());

        String otp = generateOtp();
        PasswordResetToken resetToken = new PasswordResetToken();
        resetToken.setUser(user);
        resetToken.setOtpHash(tokenHasher.hash(otp));
        resetToken.setExpiresAt(LocalDateTime.now().plusSeconds(otpTtlSeconds));
        passwordResetTokenRepository.save(resetToken);

        emailSender.send(user.getEmail(), PASSWORD_RESET_EMAIL_SUBJECT, passwordResetEmailBody(otp));
    }

    private String passwordResetEmailBody(String otp) {
        long minutes = otpTtlSeconds / 60;
        return "Your FootVerse password reset code is " + otp + ". It expires in " + minutes
                + " minutes. If you did not request this, you can safely ignore this email.";
    }

    /**
     * Verifies an emailed one-time code (security-spec §2-style single-use flow, mirrored from
     * refresh-token rotation). An expired row is deleted and rejected; a wrong code increments
     * {@code attemptCount} and destroys the row once {@code maxAttempts} is reached; a correct code
     * issues a fresh opaque reset token and re-points the row's {@code expiresAt} at the shorter
     * reset-token TTL, since the same row now enters its verified stage.
     *
     * <p>{@code noRollbackFor = BusinessException.class} preserves the writes made on the rejecting
     * paths — the expired-row delete and the wrong-code attempt increment (or the delete once
     * {@code maxAttempts} is reached) — exactly as {@link #refresh} preserves its step-5 cleanup; a
     * plain {@code @Transactional} would otherwise undo them the moment the {@link BusinessException}
     * is thrown, silently defeating both the expiry cleanup and the attempt limit. The happy path
     * never throws, so it is unaffected.</p>
     */
    @Override
    @Transactional(noRollbackFor = BusinessException.class)
    public PasswordResetTokenResponse verifyResetOtp(VerifyResetOtpRequest request) {
        String email = request.email().toLowerCase(Locale.ROOT);
        User user = userService.findByEmail(email)
                .orElseThrow(() -> new BusinessException(HttpStatus.BAD_REQUEST,
                        PASSWORD_RESET_OTP_INVALID_CODE, PASSWORD_RESET_OTP_INVALID_MESSAGE));
        PasswordResetToken resetToken = passwordResetTokenRepository.findByUserId(user.getId())
                .orElseThrow(() -> new BusinessException(HttpStatus.BAD_REQUEST,
                        PASSWORD_RESET_OTP_INVALID_CODE, PASSWORD_RESET_OTP_INVALID_MESSAGE));

        if (resetToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            passwordResetTokenRepository.delete(resetToken);
            throw new BusinessException(HttpStatus.BAD_REQUEST,
                    PASSWORD_RESET_OTP_EXPIRED_CODE, PASSWORD_RESET_OTP_EXPIRED_MESSAGE);
        }

        if (!tokenHasher.hash(request.otp()).equals(resetToken.getOtpHash())) {
            resetToken.setAttemptCount(resetToken.getAttemptCount() + 1);
            if (resetToken.getAttemptCount() >= maxAttempts) {
                passwordResetTokenRepository.delete(resetToken);
            } else {
                passwordResetTokenRepository.save(resetToken);
            }
            throw new BusinessException(HttpStatus.BAD_REQUEST,
                    PASSWORD_RESET_OTP_INVALID_CODE, PASSWORD_RESET_OTP_INVALID_MESSAGE);
        }

        String rawResetToken = generateOpaqueToken(RESET_TOKEN_BYTES);
        resetToken.setResetTokenHash(tokenHasher.hash(rawResetToken));
        resetToken.setVerifiedAt(LocalDateTime.now());
        resetToken.setExpiresAt(LocalDateTime.now().plusSeconds(resetTokenTtlSeconds));
        passwordResetTokenRepository.save(resetToken);

        return new PasswordResetTokenResponse(rawResetToken, resetTokenTtlSeconds);
    }

    /**
     * Sets a new password using a verified reset token (single-use) and revokes every refresh token
     * the account holds, ending every existing session.
     *
     * <p>{@code noRollbackFor = BusinessException.class} preserves the expired-token row deletion on
     * its rejecting path, exactly as {@link #verifyResetOtp} and {@link #refresh} preserve their own
     * cleanup writes; the happy path never throws, so it is unaffected.</p>
     */
    @Override
    @Transactional(noRollbackFor = BusinessException.class)
    public void resetPassword(ResetPasswordRequest request) {
        String resetTokenHash = tokenHasher.hash(request.resetToken());
        PasswordResetToken resetToken = passwordResetTokenRepository.findByResetTokenHash(resetTokenHash)
                .filter(token -> token.getVerifiedAt() != null)
                .orElseThrow(() -> new BusinessException(HttpStatus.BAD_REQUEST,
                        PASSWORD_RESET_TOKEN_INVALID_CODE, PASSWORD_RESET_TOKEN_INVALID_MESSAGE));

        if (resetToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            passwordResetTokenRepository.delete(resetToken);
            throw new BusinessException(HttpStatus.BAD_REQUEST,
                    PASSWORD_RESET_TOKEN_EXPIRED_CODE, PASSWORD_RESET_TOKEN_EXPIRED_MESSAGE);
        }

        User user = resetToken.getUser();
        userService.resetPassword(user, passwordEncoder.encode(request.newPassword()));
        passwordResetTokenRepository.delete(resetToken);
        refreshTokenRepository.deleteByUserId(user.getId());
    }

    private String issueRefreshToken(User user) {
        String rawToken = generateOpaqueToken(REFRESH_TOKEN_BYTES);
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setUser(user);
        refreshToken.setTokenHash(tokenHasher.hash(rawToken));
        refreshToken.setExpiresAt(LocalDateTime.now().plusSeconds(refreshTokenTtlSeconds));
        refreshTokenRepository.save(refreshToken);
        return rawToken;
    }

    private String generateOpaqueToken(int byteLength) {
        byte[] randomBytes = new byte[byteLength];
        secureRandom.nextBytes(randomBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
    }

    private String generateOtp() {
        int code = secureRandom.nextInt(OTP_BOUND);
        return String.format(OTP_FORMAT, code);
    }
}
