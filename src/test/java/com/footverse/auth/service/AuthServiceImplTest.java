package com.footverse.auth.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDateTime;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.entity.RefreshToken;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.util.TokenHasher;
import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.Role;
import com.footverse.user.entity.User;
import com.footverse.user.service.UserService;

/**
 * Unit tests for the registration flow in {@link AuthServiceImpl}.
 */
@ExtendWith(MockitoExtension.class)
class AuthServiceImplTest {

    private static final long ACCESS_TTL = 900L;
    private static final long REFRESH_TTL = 2_592_000L;

    @Mock
    private UserService userService;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtUtil jwtUtil;

    private final TokenHasher tokenHasher = new TokenHasher();

    private AuthServiceImpl authService;

    @BeforeEach
    void setUp() {
        authService = new AuthServiceImpl(userService, refreshTokenRepository, passwordEncoder, jwtUtil,
                tokenHasher, ACCESS_TTL, REFRESH_TTL);
    }

    private RegisterRequest request() {
        return new RegisterRequest("User@Example.com", "Password1", "Test User", "0912345678");
    }

    private User savedUser() {
        User user = new User();
        user.setEmail("user@example.com");
        user.setPassword("$2a$10$encoded");
        user.setFullName("Test User");
        user.setPhone("0912345678");
        user.setRole(Role.CUSTOMER);
        user.setEnabled(true);
        return user;
    }

    /**
     * A successful registration encodes the password, stores only the refresh-token hash, and
     * returns the token pair per dto-spec.
     */
    @Test
    void registerIssuesTokensAndStoresHashedRefreshToken() {
        User user = savedUser();
        UserResponse userResponse = new UserResponse(1L, "user@example.com", "Test User", "0912345678",
                null, Role.CUSTOMER, true, LocalDateTime.now(), LocalDateTime.now());
        when(userService.existsByEmail("user@example.com")).thenReturn(false);
        when(userService.existsByPhone("0912345678")).thenReturn(false);
        when(passwordEncoder.encode("Password1")).thenReturn("$2a$10$encoded");
        when(userService.createUser("user@example.com", "$2a$10$encoded", "Test User", "0912345678"))
                .thenReturn(user);
        when(jwtUtil.createAccessToken("user@example.com")).thenReturn("access-token");
        when(userService.toResponse(user)).thenReturn(userResponse);

        AuthResponse response = authService.register(request());

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.expiresIn()).isEqualTo(ACCESS_TTL);
        assertThat(response.user()).isEqualTo(userResponse);
        assertThat(response.refreshToken()).isNotBlank();
        verify(passwordEncoder).encode("Password1");

        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).save(captor.capture());
        RefreshToken stored = captor.getValue();
        assertThat(stored.getUser()).isEqualTo(user);
        assertThat(stored.getTokenHash()).isEqualTo(tokenHasher.hash(response.refreshToken()));
        assertThat(stored.getTokenHash()).isNotEqualTo(response.refreshToken());
        assertThat(stored.getTokenHash()).hasSize(64);
        assertThat(stored.getExpiresAt()).isAfter(LocalDateTime.now());
    }

    /**
     * A duplicate email raises a 409 {@code USER_EMAIL_DUPLICATED} and creates no user.
     */
    @Test
    void duplicateEmailIsRejected() {
        when(userService.existsByEmail("user@example.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(request()))
                .isInstanceOfSatisfying(DuplicateResourceException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("USER_EMAIL_DUPLICATED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.CONFLICT);
                });
        verify(userService, never()).createUser(any(), any(), any(), any());
    }

    /**
     * A duplicate phone raises a 409 {@code USER_PHONE_DUPLICATED} and creates no user.
     */
    @Test
    void duplicatePhoneIsRejected() {
        when(userService.existsByEmail("user@example.com")).thenReturn(false);
        when(userService.existsByPhone("0912345678")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(request()))
                .isInstanceOfSatisfying(DuplicateResourceException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("USER_PHONE_DUPLICATED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.CONFLICT);
                });
        verify(userService, never()).createUser(eq("user@example.com"), any(), any(), any());
    }
}
