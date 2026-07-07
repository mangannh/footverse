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
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.entity.RefreshToken;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
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
 */
@Service
public class AuthServiceImpl implements AuthService {

    private static final int REFRESH_TOKEN_BYTES = 32;
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

    private final SecureRandom secureRandom = new SecureRandom();

    private final UserService userService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final TokenHasher tokenHasher;
    private final CurrentUserProvider currentUserProvider;
    private final long accessTokenTtlSeconds;
    private final long refreshTokenTtlSeconds;

    /**
     * Creates the service.
     *
     * @param userService            the user-module façade
     * @param refreshTokenRepository  the refresh-token store
     * @param passwordEncoder         the BCrypt password encoder
     * @param jwtUtil                 the access-token utility
     * @param tokenHasher             the SHA-256 hasher for refresh tokens
     * @param currentUserProvider     the authenticated-user access point (for logout ownership)
     * @param accessTokenTtlSeconds   the access-token TTL in seconds (for {@code expiresIn})
     * @param refreshTokenTtlSeconds  the refresh-token TTL in seconds
     */
    public AuthServiceImpl(UserService userService,
                           RefreshTokenRepository refreshTokenRepository,
                           PasswordEncoder passwordEncoder,
                           JwtUtil jwtUtil,
                           TokenHasher tokenHasher,
                           CurrentUserProvider currentUserProvider,
                           @Value("${footverse.jwt.access-token-ttl-seconds}") long accessTokenTtlSeconds,
                           @Value("${footverse.jwt.refresh-token-ttl-seconds}") long refreshTokenTtlSeconds) {
        this.userService = userService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.tokenHasher = tokenHasher;
        this.currentUserProvider = currentUserProvider;
        this.accessTokenTtlSeconds = accessTokenTtlSeconds;
        this.refreshTokenTtlSeconds = refreshTokenTtlSeconds;
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

    private String issueRefreshToken(User user) {
        String rawToken = generateRawRefreshToken();
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setUser(user);
        refreshToken.setTokenHash(tokenHasher.hash(rawToken));
        refreshToken.setExpiresAt(LocalDateTime.now().plusSeconds(refreshTokenTtlSeconds));
        refreshTokenRepository.save(refreshToken);
        return rawToken;
    }

    private String generateRawRefreshToken() {
        byte[] randomBytes = new byte[REFRESH_TOKEN_BYTES];
        secureRandom.nextBytes(randomBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
    }
}
