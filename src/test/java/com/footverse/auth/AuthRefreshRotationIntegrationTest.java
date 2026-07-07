package com.footverse.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
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
 * End-to-end refresh-rotation tests against the real database. They prove the single-use
 * rotation semantics that pure-Mockito tests cannot: a rotated token is deleted and unusable,
 * consecutive refreshes with each new token succeed, and register/login stay unaffected.
 *
 * <p>Each test runs in its own transaction that is rolled back afterwards, so it sets up its own
 * fixtures and leaves no persisted state.</p>
 */
@SpringBootTest
@Transactional
class AuthRefreshRotationIntegrationTest {

    private final AuthService authService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TokenHasher tokenHasher;

    AuthRefreshRotationIntegrationTest(@Autowired AuthService authService,
                                       @Autowired RefreshTokenRepository refreshTokenRepository,
                                       @Autowired TokenHasher tokenHasher) {
        this.authService = authService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.tokenHasher = tokenHasher;
    }

    private AuthResponse registerUser() {
        return authService.register(new RegisterRequest(
                "refresh-flow@example.com", "Password1", "Refresh Flow", "0900000015"));
    }

    private boolean rowExistsFor(String rawRefreshToken) {
        return refreshTokenRepository.findByTokenHash(tokenHasher.hash(rawRefreshToken)).isPresent();
    }

    /**
     * A valid refresh rotates the pair: the old row is gone, a row for the new token exists, and a
     * fresh access token is returned.
     */
    @Test
    void refreshRotatesAndDeletesOldRow() {
        AuthResponse registered = registerUser();

        AuthResponse refreshed = authService.refresh(new RefreshTokenRequest(registered.refreshToken()));

        assertThat(refreshed.accessToken()).isNotBlank();
        assertThat(refreshed.refreshToken()).isNotBlank().isNotEqualTo(registered.refreshToken());
        assertThat(rowExistsFor(registered.refreshToken())).isFalse();
        assertThat(rowExistsFor(refreshed.refreshToken())).isTrue();
    }

    /**
     * A rotated (reused) refresh token no longer works — it is rejected with
     * {@code REFRESH_TOKEN_INVALID}.
     */
    @Test
    void reusedRefreshTokenIsRejected() {
        AuthResponse registered = registerUser();
        authService.refresh(new RefreshTokenRequest(registered.refreshToken()));

        assertThatThrownBy(() -> authService.refresh(new RefreshTokenRequest(registered.refreshToken())))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("REFRESH_TOKEN_INVALID"));
    }

    /**
     * Consecutive refreshes, each with the latest issued token, all succeed; every superseded
     * token is deleted and only the newest one remains live.
     */
    @Test
    void consecutiveRefreshesWithNewTokensSucceed() {
        AuthResponse registered = registerUser();

        AuthResponse first = authService.refresh(new RefreshTokenRequest(registered.refreshToken()));
        AuthResponse second = authService.refresh(new RefreshTokenRequest(first.refreshToken()));
        AuthResponse third = authService.refresh(new RefreshTokenRequest(second.refreshToken()));

        assertThat(third.refreshToken()).isNotBlank()
                .isNotEqualTo(first.refreshToken())
                .isNotEqualTo(second.refreshToken());
        assertThat(rowExistsFor(first.refreshToken())).isFalse();
        assertThat(rowExistsFor(second.refreshToken())).isFalse();
        assertThat(rowExistsFor(third.refreshToken())).isTrue();
    }

    /**
     * Refresh does not affect register/login: after a rotation the account can still log in and
     * the login itself issues yet another usable refresh token (multi-device rows coexist).
     */
    @Test
    void refreshDoesNotBreakLogin() {
        AuthResponse registered = registerUser();
        authService.refresh(new RefreshTokenRequest(registered.refreshToken()));

        AuthResponse loggedIn = authService.login(new LoginRequest("refresh-flow@example.com", "Password1"));

        assertThat(loggedIn.accessToken()).isNotBlank();
        assertThat(rowExistsFor(loggedIn.refreshToken())).isTrue();
        assertThat(authService.refresh(new RefreshTokenRequest(loggedIn.refreshToken())).refreshToken())
                .isNotBlank();
    }
}
