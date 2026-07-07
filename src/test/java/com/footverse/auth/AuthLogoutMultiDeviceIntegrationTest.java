package com.footverse.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Collections;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.auth.service.AuthService;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.util.TokenHasher;

/**
 * End-to-end multi-device logout test against the real database: two devices log in, one logs
 * out, and only that device's token is revoked while the other keeps working. This proves the
 * frozen multi-device semantics (security-spec §2): logout revokes only the presented token.
 *
 * <p>Runs in a rolled-back transaction and clears the security context after each test.</p>
 */
@SpringBootTest
@Transactional
class AuthLogoutMultiDeviceIntegrationTest {

    private static final String EMAIL = "multi-device@example.com";
    private static final String PASSWORD = "Password1";
    private static final String PHONE = "0900000017";

    private final AuthService authService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TokenHasher tokenHasher;

    AuthLogoutMultiDeviceIntegrationTest(@Autowired AuthService authService,
                                         @Autowired RefreshTokenRepository refreshTokenRepository,
                                         @Autowired TokenHasher tokenHasher) {
        this.authService = authService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.tokenHasher = tokenHasher;
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private void authenticateAs(String email) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(email, null, Collections.emptyList()));
    }

    private boolean rowExistsFor(String rawRefreshToken) {
        return refreshTokenRepository.findByTokenHash(tokenHasher.hash(rawRefreshToken)).isPresent();
    }

    /**
     * With two devices logged in, logging out device 1's token revokes only that token: device
     * 1's row is gone and can no longer refresh, while device 2's token stays live and refreshes
     * normally.
     */
    @Test
    void logoutRevokesOnlyThePresentedDeviceToken() {
        AuthResponse device1 = authService.register(
                new RegisterRequest(EMAIL, PASSWORD, "Multi Device", PHONE));
        AuthResponse device2 = authService.login(new LoginRequest(EMAIL, PASSWORD));
        assertThat(rowExistsFor(device1.refreshToken())).isTrue();
        assertThat(rowExistsFor(device2.refreshToken())).isTrue();

        authenticateAs(EMAIL);
        authService.logout(new RefreshTokenRequest(device1.refreshToken()));

        assertThat(rowExistsFor(device1.refreshToken())).isFalse();
        assertThat(rowExistsFor(device2.refreshToken())).isTrue();

        assertThatThrownBy(() -> authService.refresh(new RefreshTokenRequest(device1.refreshToken())))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("REFRESH_TOKEN_INVALID"));

        AuthResponse device2Refreshed = authService.refresh(new RefreshTokenRequest(device2.refreshToken()));
        assertThat(device2Refreshed.refreshToken()).isNotBlank().isNotEqualTo(device2.refreshToken());
        assertThat(rowExistsFor(device2Refreshed.refreshToken())).isTrue();
    }
}
