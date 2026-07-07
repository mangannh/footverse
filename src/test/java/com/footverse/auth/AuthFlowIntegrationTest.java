package com.footverse.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Collections;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.auth.service.AuthService;
import com.footverse.common.util.TokenHasher;
import com.footverse.support.AuthFixtures;

/**
 * The canonical Sprint 1 end-to-end authentication flow against the real database:
 * {@code register → login → refresh → logout}. Nothing in the business flow is mocked; the
 * persisted refresh-token state is asserted after every step.
 *
 * <p>Runs in a rolled-back transaction and clears the security context after each test.</p>
 */
@SpringBootTest
@Transactional
class AuthFlowIntegrationTest {

    private static final String EMAIL = "flow@example.com";
    private static final String PHONE = "0900000020";

    private final AuthService authService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TokenHasher tokenHasher;

    AuthFlowIntegrationTest(@Autowired AuthService authService,
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
     * register → login → refresh → logout: each step issues/rotates/revokes exactly the expected
     * refresh-token rows, and the untouched register-session token survives the whole flow.
     */
    @Test
    void registerLoginRefreshLogoutFlow() {
        // Register issues the first token pair and persists its refresh row.
        AuthResponse registered = authService.register(
                AuthFixtures.registerRequest(EMAIL, PHONE, "Flow User"));
        assertThat(registered.accessToken()).isNotBlank();
        assertThat(registered.tokenType()).isEqualTo("Bearer");
        assertThat(rowExistsFor(registered.refreshToken())).isTrue();

        // Login (a second session) issues a new pair without touching the register-session row.
        AuthResponse loggedIn = authService.login(AuthFixtures.loginRequest(EMAIL));
        assertThat(loggedIn.accessToken()).isNotBlank();
        assertThat(loggedIn.refreshToken()).isNotEqualTo(registered.refreshToken());
        assertThat(rowExistsFor(loggedIn.refreshToken())).isTrue();
        assertThat(rowExistsFor(registered.refreshToken())).isTrue();

        // Refresh rotates the login-session token: old row gone, new row present.
        AuthResponse refreshed = authService.refresh(AuthFixtures.refreshRequest(loggedIn.refreshToken()));
        assertThat(refreshed.refreshToken()).isNotBlank().isNotEqualTo(loggedIn.refreshToken());
        assertThat(rowExistsFor(loggedIn.refreshToken())).isFalse();
        assertThat(rowExistsFor(refreshed.refreshToken())).isTrue();

        // Logout revokes only the presented (refreshed) token.
        authenticateAs(EMAIL);
        authService.logout(AuthFixtures.refreshRequest(refreshed.refreshToken()));
        assertThat(rowExistsFor(refreshed.refreshToken())).isFalse();

        // The independent register-session token is untouched by the whole flow.
        assertThat(rowExistsFor(registered.refreshToken())).isTrue();
    }
}
