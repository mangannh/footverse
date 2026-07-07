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
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.entity.RefreshToken;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
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
 * every login (multi-device) without overwriting existing ones.
 */
@Service
public class AuthServiceImpl implements AuthService {

    private static final int REFRESH_TOKEN_BYTES = 32;
    private static final String TOKEN_TYPE = "Bearer";
    private static final String INVALID_CREDENTIALS_CODE = "INVALID_CREDENTIALS";
    private static final String INVALID_CREDENTIALS_MESSAGE = "Invalid email or password";
    private static final String ACCOUNT_DISABLED_CODE = "ACCOUNT_DISABLED";
    private static final String ACCOUNT_DISABLED_MESSAGE = "Account is disabled";

    private final SecureRandom secureRandom = new SecureRandom();

    private final UserService userService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final TokenHasher tokenHasher;
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
     * @param accessTokenTtlSeconds   the access-token TTL in seconds (for {@code expiresIn})
     * @param refreshTokenTtlSeconds  the refresh-token TTL in seconds
     */
    public AuthServiceImpl(UserService userService,
                           RefreshTokenRepository refreshTokenRepository,
                           PasswordEncoder passwordEncoder,
                           JwtUtil jwtUtil,
                           TokenHasher tokenHasher,
                           @Value("${footverse.jwt.access-token-ttl-seconds}") long accessTokenTtlSeconds,
                           @Value("${footverse.jwt.refresh-token-ttl-seconds}") long refreshTokenTtlSeconds) {
        this.userService = userService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.tokenHasher = tokenHasher;
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
