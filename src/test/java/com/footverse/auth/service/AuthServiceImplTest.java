package com.footverse.auth.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

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
import com.footverse.user.entity.Role;
import com.footverse.user.entity.User;
import com.footverse.user.service.UserService;

/**
 * Unit tests for {@link AuthServiceImpl}: registration, login, refresh rotation, logout, and the
 * password-reset flow (Sprint 13 Task 05).
 */
@ExtendWith(MockitoExtension.class)
class AuthServiceImplTest {

    private static final long ACCESS_TTL = 900L;
    private static final long REFRESH_TTL = 2_592_000L;
    private static final long OTP_TTL = 600L;
    private static final long RESET_TOKEN_TTL = 900L;
    private static final int MAX_ATTEMPTS = 5;

    @Mock
    private UserService userService;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @Mock
    private PasswordResetTokenRepository passwordResetTokenRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtUtil jwtUtil;

    @Mock
    private CurrentUserProvider currentUserProvider;

    @Mock
    private EmailSender emailSender;

    private final TokenHasher tokenHasher = new TokenHasher();

    private AuthServiceImpl authService;

    @BeforeEach
    void setUp() {
        authService = new AuthServiceImpl(userService, refreshTokenRepository, passwordResetTokenRepository,
                passwordEncoder, jwtUtil, tokenHasher, currentUserProvider, emailSender,
                ACCESS_TTL, REFRESH_TTL, OTP_TTL, RESET_TOKEN_TTL, MAX_ATTEMPTS);
    }

    private PasswordResetToken resetTokenRow(User user, String otp, LocalDateTime expiresAt) {
        PasswordResetToken row = new PasswordResetToken();
        row.setUser(user);
        row.setOtpHash(tokenHasher.hash(otp));
        row.setExpiresAt(expiresAt);
        return row;
    }

    private RegisterRequest request() {
        return new RegisterRequest("User@Example.com", "Password1", "Test User", "0912345678");
    }

    private LoginRequest loginRequest() {
        return new LoginRequest("User@Example.com", "Password1");
    }

    private User userWithId(Long id) {
        User user = savedUser();
        user.setId(id);
        return user;
    }

    private RefreshToken refreshTokenRow(User user, String rawToken, LocalDateTime expiresAt) {
        RefreshToken row = new RefreshToken();
        row.setUser(user);
        row.setTokenHash(tokenHasher.hash(rawToken));
        row.setExpiresAt(expiresAt);
        return row;
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

    /**
     * A valid login (email matched case-insensitively, BCrypt password match, enabled account)
     * issues a token pair and stores only the refresh-token hash.
     */
    @Test
    void loginIssuesTokensForValidCredentials() {
        User user = savedUser();
        UserResponse userResponse = new UserResponse(1L, "user@example.com", "Test User", "0912345678",
                null, Role.CUSTOMER, true, LocalDateTime.now(), LocalDateTime.now());
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("Password1", "$2a$10$encoded")).thenReturn(true);
        when(jwtUtil.createAccessToken("user@example.com")).thenReturn("access-token");
        when(userService.toResponse(user)).thenReturn(userResponse);

        AuthResponse response = authService.login(loginRequest());

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.expiresIn()).isEqualTo(ACCESS_TTL);
        assertThat(response.user()).isEqualTo(userResponse);
        assertThat(response.refreshToken()).isNotBlank();

        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).save(captor.capture());
        RefreshToken stored = captor.getValue();
        assertThat(stored.getUser()).isEqualTo(user);
        assertThat(stored.getTokenHash()).isEqualTo(tokenHasher.hash(response.refreshToken()));
        assertThat(stored.getExpiresAt()).isAfter(LocalDateTime.now());
    }

    /**
     * A wrong password raises a 401 {@code INVALID_CREDENTIALS} and issues no token.
     */
    @Test
    void loginWithWrongPasswordIsRejected() {
        User user = savedUser();
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("Password1", "$2a$10$encoded")).thenReturn(false);

        assertThatThrownBy(() -> authService.login(loginRequest()))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("INVALID_CREDENTIALS");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
        verify(refreshTokenRepository, never()).save(any());
    }

    /**
     * An unknown email raises a 401 {@code INVALID_CREDENTIALS} — indistinguishable from a wrong
     * password — and issues no token.
     */
    @Test
    void loginWithUnknownEmailIsRejected() {
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(loginRequest()))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("INVALID_CREDENTIALS");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
        verify(refreshTokenRepository, never()).save(any());
    }

    /**
     * A disabled account (valid credentials) raises a 401 {@code ACCOUNT_DISABLED} and issues no
     * token.
     */
    @Test
    void loginWithDisabledAccountIsRejected() {
        User user = savedUser();
        user.setEnabled(false);
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("Password1", "$2a$10$encoded")).thenReturn(true);

        assertThatThrownBy(() -> authService.login(loginRequest()))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("ACCOUNT_DISABLED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
        verify(refreshTokenRepository, never()).save(any());
    }

    /**
     * Each login inserts a new refresh-token row (multi-device) with a distinct token — existing
     * rows are never overwritten or deleted.
     */
    @Test
    void eachLoginInsertsANewRefreshTokenRow() {
        User user = savedUser();
        UserResponse userResponse = new UserResponse(1L, "user@example.com", "Test User", "0912345678",
                null, Role.CUSTOMER, true, LocalDateTime.now(), LocalDateTime.now());
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("Password1", "$2a$10$encoded")).thenReturn(true);
        when(jwtUtil.createAccessToken("user@example.com")).thenReturn("access-token");
        when(userService.toResponse(user)).thenReturn(userResponse);

        AuthResponse first = authService.login(loginRequest());
        AuthResponse second = authService.login(loginRequest());

        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository, times(2)).save(captor.capture());
        List<RefreshToken> stored = captor.getAllValues();
        assertThat(first.refreshToken()).isNotEqualTo(second.refreshToken());
        assertThat(stored.get(0).getTokenHash()).isNotEqualTo(stored.get(1).getTokenHash());
        verify(refreshTokenRepository, never()).delete(any());
        verify(refreshTokenRepository, never()).deleteAll();
    }

    /**
     * A valid refresh rotates the token: the old row is deleted and a new access/refresh pair is
     * issued (canonical flow steps 7-12), with the new refresh hash differing from the old.
     */
    @Test
    void refreshRotatesTokenForValidToken() {
        User user = savedUser();
        UserResponse userResponse = new UserResponse(1L, "user@example.com", "Test User", "0912345678",
                null, Role.CUSTOMER, true, LocalDateTime.now(), LocalDateTime.now());
        RefreshToken existing = refreshTokenRow(user, "old-refresh-token", LocalDateTime.now().plusDays(30));
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("old-refresh-token")))
                .thenReturn(Optional.of(existing));
        when(jwtUtil.createAccessToken("user@example.com")).thenReturn("new-access-token");
        when(userService.toResponse(user)).thenReturn(userResponse);

        AuthResponse response = authService.refresh(new RefreshTokenRequest("old-refresh-token"));

        assertThat(response.accessToken()).isEqualTo("new-access-token");
        assertThat(response.tokenType()).isEqualTo("Bearer");
        assertThat(response.expiresIn()).isEqualTo(ACCESS_TTL);
        assertThat(response.user()).isEqualTo(userResponse);
        assertThat(response.refreshToken()).isNotBlank().isNotEqualTo("old-refresh-token");

        verify(refreshTokenRepository).delete(existing);
        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).save(captor.capture());
        RefreshToken inserted = captor.getValue();
        assertThat(inserted.getUser()).isEqualTo(user);
        assertThat(inserted.getTokenHash()).isEqualTo(tokenHasher.hash(response.refreshToken()));
        assertThat(inserted.getTokenHash()).isNotEqualTo(existing.getTokenHash());
        assertThat(inserted.getExpiresAt()).isAfter(LocalDateTime.now());
    }

    /**
     * An unknown refresh token (no matching row) raises a 401 {@code REFRESH_TOKEN_INVALID} and
     * neither deletes nor inserts a row. A rotated (reused) token hits this exact path.
     */
    @Test
    void refreshWithUnknownTokenIsRejected() {
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("missing-token")))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.refresh(new RefreshTokenRequest("missing-token")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("REFRESH_TOKEN_INVALID");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
        verify(refreshTokenRepository, never()).delete(any());
        verify(refreshTokenRepository, never()).save(any());
    }

    /**
     * An expired refresh token is deleted from the store and raises a 401
     * {@code REFRESH_TOKEN_EXPIRED}; no new row is issued (canonical flow step 5).
     */
    @Test
    void refreshWithExpiredTokenDeletesRowAndIsRejected() {
        User user = savedUser();
        RefreshToken existing = refreshTokenRow(user, "expired-token", LocalDateTime.now().minusSeconds(1));
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("expired-token")))
                .thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> authService.refresh(new RefreshTokenRequest("expired-token")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("REFRESH_TOKEN_EXPIRED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
        verify(refreshTokenRepository).delete(existing);
        verify(refreshTokenRepository, never()).save(any());
    }

    /**
     * A refresh for a disabled account is rejected with a 401 {@code ACCOUNT_DISABLED}; the row is
     * left untouched (the delete at step 7 is never reached) and no new token is issued.
     */
    @Test
    void refreshForDisabledAccountIsRejected() {
        User user = savedUser();
        user.setEnabled(false);
        RefreshToken existing = refreshTokenRow(user, "disabled-user-token", LocalDateTime.now().plusDays(30));
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("disabled-user-token")))
                .thenReturn(Optional.of(existing));

        assertThatThrownBy(() -> authService.refresh(new RefreshTokenRequest("disabled-user-token")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("ACCOUNT_DISABLED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
        verify(refreshTokenRepository, never()).delete(any());
        verify(refreshTokenRepository, never()).save(any());
    }

    /**
     * A logout by the token's owner deletes exactly that row (the caller's own token is revoked).
     */
    @Test
    void logoutDeletesOwnPresentedToken() {
        User user = userWithId(1L);
        RefreshToken existing = refreshTokenRow(user, "device-token", LocalDateTime.now().plusDays(30));
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("device-token")))
                .thenReturn(Optional.of(existing));
        when(currentUserProvider.getCurrentUser()).thenReturn(user);

        authService.logout(new RefreshTokenRequest("device-token"));

        verify(refreshTokenRepository).delete(existing);
    }

    /**
     * Logging out an unknown or already-revoked token (no matching row) is an idempotent no-op:
     * it returns normally, deletes nothing, and never even consults the current user — so it
     * cannot leak whether the token exists.
     */
    @Test
    void logoutWithUnknownOrRevokedTokenIsNoOp() {
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("gone-token")))
                .thenReturn(Optional.empty());

        authService.logout(new RefreshTokenRequest("gone-token"));

        verify(refreshTokenRepository, never()).delete(any());
        verify(currentUserProvider, never()).getCurrentUser();
    }

    /**
     * Logging out a refresh token owned by another user is rejected with 403
     * {@code REFRESH_TOKEN_FORBIDDEN}, and the victim's row is left intact.
     */
    @Test
    void logoutAnotherUsersTokenIsForbiddenAndKeepsRow() {
        User owner = userWithId(1L);
        User caller = userWithId(2L);
        RefreshToken existing = refreshTokenRow(owner, "victim-token", LocalDateTime.now().plusDays(30));
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("victim-token")))
                .thenReturn(Optional.of(existing));
        when(currentUserProvider.getCurrentUser()).thenReturn(caller);

        assertThatThrownBy(() -> authService.logout(new RefreshTokenRequest("victim-token")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("REFRESH_TOKEN_FORBIDDEN");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.FORBIDDEN);
                });
        verify(refreshTokenRepository, never()).delete(any());
    }

    /**
     * Logout revokes only the single presented token, never a bulk delete of the user's other
     * devices.
     */
    @Test
    void logoutRevokesOnlyThePresentedToken() {
        User user = userWithId(1L);
        RefreshToken presented = refreshTokenRow(user, "presented-token", LocalDateTime.now().plusDays(30));
        when(refreshTokenRepository.findByTokenHash(tokenHasher.hash("presented-token")))
                .thenReturn(Optional.of(presented));
        when(currentUserProvider.getCurrentUser()).thenReturn(user);

        authService.logout(new RefreshTokenRequest("presented-token"));

        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(refreshTokenRepository).delete(captor.capture());
        assertThat(captor.getValue()).isEqualTo(presented);
        verify(refreshTokenRepository, never()).deleteAll();
    }

    /**
     * A forgot-password request for a registered, enabled account clears any stale attempt, stores
     * only the OTP's hash with the configured TTL, and emails the raw code — captured here through
     * the {@link EmailSender} fake rather than asserted against a log.
     */
    @Test
    void forgotPasswordForKnownEnabledAccountStoresHashedOtpAndSendsEmail() {
        User user = userWithId(1L);
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));

        authService.forgotPassword(new ForgotPasswordRequest("User@Example.com"));

        verify(passwordResetTokenRepository).deleteByUserId(1L);
        ArgumentCaptor<PasswordResetToken> captor = ArgumentCaptor.forClass(PasswordResetToken.class);
        verify(passwordResetTokenRepository).save(captor.capture());
        PasswordResetToken saved = captor.getValue();
        assertThat(saved.getUser()).isEqualTo(user);
        assertThat(saved.getOtpHash()).hasSize(64);
        assertThat(saved.getExpiresAt()).isAfter(LocalDateTime.now());

        ArgumentCaptor<String> bodyCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailSender).send(eq("user@example.com"), any(), bodyCaptor.capture());
        String rawOtp = saved.getOtpHash();
        assertThat(tokenHasher.hash(extractSixDigitCode(bodyCaptor.getValue()))).isEqualTo(rawOtp);
    }

    private String extractSixDigitCode(String emailBody) {
        Matcher matcher = Pattern.compile("\\d{6}").matcher(emailBody);
        assertThat(matcher.find()).isTrue();
        return matcher.group();
    }

    /**
     * An unknown email answers with no exception (the controller still returns {@code 200}) and
     * sends no email — the non-enumeration contract at the service layer.
     */
    @Test
    void forgotPasswordForUnknownEmailSendsNoEmail() {
        when(userService.findByEmail("nobody@example.com")).thenReturn(Optional.empty());

        authService.forgotPassword(new ForgotPasswordRequest("nobody@example.com"));

        verify(passwordResetTokenRepository, never()).save(any());
        verify(emailSender, never()).send(any(), any(), any());
    }

    /**
     * A disabled account answers with no exception and sends no email, exactly like an unknown
     * email — the response must not distinguish the two.
     */
    @Test
    void forgotPasswordForDisabledAccountSendsNoEmail() {
        User user = savedUser();
        user.setEnabled(false);
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));

        authService.forgotPassword(new ForgotPasswordRequest("user@example.com"));

        verify(passwordResetTokenRepository, never()).save(any());
        verify(emailSender, never()).send(any(), any(), any());
    }

    /**
     * A correct one-time code issues an opaque reset token, stores only its hash alongside
     * {@code verifiedAt}, and re-points {@code expiresAt} at the (shorter) reset-token TTL.
     */
    @Test
    void verifyResetOtpWithCorrectCodeIssuesResetToken() {
        User user = userWithId(1L);
        PasswordResetToken row = resetTokenRow(user, "123456", LocalDateTime.now().plusMinutes(5));
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordResetTokenRepository.findByUserId(1L)).thenReturn(Optional.of(row));

        PasswordResetTokenResponse response =
                authService.verifyResetOtp(new VerifyResetOtpRequest("User@Example.com", "123456"));

        assertThat(response.resetToken()).isNotBlank();
        assertThat(response.expiresIn()).isEqualTo(RESET_TOKEN_TTL);
        ArgumentCaptor<PasswordResetToken> captor = ArgumentCaptor.forClass(PasswordResetToken.class);
        verify(passwordResetTokenRepository).save(captor.capture());
        PasswordResetToken saved = captor.getValue();
        assertThat(saved.getResetTokenHash()).isEqualTo(tokenHasher.hash(response.resetToken()));
        assertThat(saved.getVerifiedAt()).isNotNull();
        assertThat(saved.getExpiresAt()).isAfter(LocalDateTime.now().plusMinutes(10));
        verify(passwordResetTokenRepository, never()).delete(any());
    }

    /**
     * An unknown email is rejected as 400 {@code PASSWORD_RESET_OTP_INVALID} — indistinguishable
     * from a wrong code for an existing attempt.
     */
    @Test
    void verifyResetOtpWithUnknownEmailIsRejected() {
        when(userService.findByEmail("nobody@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.verifyResetOtp(
                new VerifyResetOtpRequest("nobody@example.com", "123456")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("PASSWORD_RESET_OTP_INVALID");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                });
    }

    /**
     * An expired attempt is deleted and rejected as 400 {@code PASSWORD_RESET_OTP_EXPIRED}.
     */
    @Test
    void verifyResetOtpWithExpiredAttemptDeletesRowAndIsRejected() {
        User user = userWithId(1L);
        PasswordResetToken row = resetTokenRow(user, "123456", LocalDateTime.now().minusSeconds(1));
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordResetTokenRepository.findByUserId(1L)).thenReturn(Optional.of(row));

        assertThatThrownBy(() -> authService.verifyResetOtp(
                new VerifyResetOtpRequest("user@example.com", "123456")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("PASSWORD_RESET_OTP_EXPIRED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                });
        verify(passwordResetTokenRepository).delete(row);
        verify(passwordResetTokenRepository, never()).save(any());
    }

    /**
     * A wrong code below the attempt limit increments {@code attemptCount} and is rejected as 400
     * {@code PASSWORD_RESET_OTP_INVALID}; the row survives for a further attempt.
     */
    @Test
    void verifyResetOtpWithWrongCodeIncrementsAttemptsAndSurvives() {
        User user = userWithId(1L);
        PasswordResetToken row = resetTokenRow(user, "123456", LocalDateTime.now().plusMinutes(5));
        row.setAttemptCount(MAX_ATTEMPTS - 2);
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordResetTokenRepository.findByUserId(1L)).thenReturn(Optional.of(row));

        assertThatThrownBy(() -> authService.verifyResetOtp(
                new VerifyResetOtpRequest("user@example.com", "999999")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("PASSWORD_RESET_OTP_INVALID");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                });
        verify(passwordResetTokenRepository, never()).delete(any());
        ArgumentCaptor<PasswordResetToken> captor = ArgumentCaptor.forClass(PasswordResetToken.class);
        verify(passwordResetTokenRepository).save(captor.capture());
        assertThat(captor.getValue().getAttemptCount()).isEqualTo(MAX_ATTEMPTS - 1);
    }

    /**
     * The attempt that reaches {@code maxAttempts} destroys the row instead of saving it, so the
     * next attempt finds nothing and is rejected the same as an unknown attempt.
     */
    @Test
    void verifyResetOtpReachingMaxAttemptsDestroysRow() {
        User user = userWithId(1L);
        PasswordResetToken row = resetTokenRow(user, "123456", LocalDateTime.now().plusMinutes(5));
        row.setAttemptCount(MAX_ATTEMPTS - 1);
        when(userService.findByEmail("user@example.com")).thenReturn(Optional.of(user));
        when(passwordResetTokenRepository.findByUserId(1L)).thenReturn(Optional.of(row));

        assertThatThrownBy(() -> authService.verifyResetOtp(
                new VerifyResetOtpRequest("user@example.com", "999999")))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("PASSWORD_RESET_OTP_INVALID"));
        verify(passwordResetTokenRepository).delete(row);
        verify(passwordResetTokenRepository, never()).save(any());
    }

    /**
     * A successful reset re-encodes the password through {@link UserService}, consumes the reset
     * row (single-use), and revokes every refresh token the account holds.
     */
    @Test
    void resetPasswordWithVerifiedTokenUpdatesPasswordAndRevokesSessions() {
        User user = userWithId(1L);
        PasswordResetToken row = resetTokenRow(user, "123456", LocalDateTime.now().plusMinutes(10));
        row.setResetTokenHash(tokenHasher.hash("verified-reset-token"));
        row.setVerifiedAt(LocalDateTime.now());
        when(passwordResetTokenRepository.findByResetTokenHash(tokenHasher.hash("verified-reset-token")))
                .thenReturn(Optional.of(row));
        when(passwordEncoder.encode("NewPassword1")).thenReturn("$2a$10$newEncoded");

        authService.resetPassword(new ResetPasswordRequest("verified-reset-token", "NewPassword1"));

        verify(userService).resetPassword(user, "$2a$10$newEncoded");
        verify(passwordResetTokenRepository).delete(row);
        verify(refreshTokenRepository).deleteByUserId(1L);
    }

    /**
     * An unknown reset token is rejected as 400 {@code PASSWORD_RESET_TOKEN_INVALID}; nothing is
     * changed.
     */
    @Test
    void resetPasswordWithUnknownTokenIsRejected() {
        when(passwordResetTokenRepository.findByResetTokenHash(tokenHasher.hash("missing-token")))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> authService.resetPassword(
                new ResetPasswordRequest("missing-token", "NewPassword1")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("PASSWORD_RESET_TOKEN_INVALID");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                });
        verify(userService, never()).resetPassword(any(), any());
        verify(refreshTokenRepository, never()).deleteByUserId(any());
    }

    /**
     * A reset token whose OTP step was never verified ({@code verifiedAt} unset) is rejected as 400
     * {@code PASSWORD_RESET_TOKEN_INVALID} — the row exists but is not yet in its reset stage.
     */
    @Test
    void resetPasswordWithUnverifiedTokenIsRejected() {
        User user = userWithId(1L);
        PasswordResetToken row = resetTokenRow(user, "123456", LocalDateTime.now().plusMinutes(10));
        row.setResetTokenHash(tokenHasher.hash("unverified-token"));
        when(passwordResetTokenRepository.findByResetTokenHash(tokenHasher.hash("unverified-token")))
                .thenReturn(Optional.of(row));

        assertThatThrownBy(() -> authService.resetPassword(
                new ResetPasswordRequest("unverified-token", "NewPassword1")))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("PASSWORD_RESET_TOKEN_INVALID"));
        verify(userService, never()).resetPassword(any(), any());
    }

    /**
     * An expired reset token is deleted and rejected as 400 {@code PASSWORD_RESET_TOKEN_EXPIRED}.
     */
    @Test
    void resetPasswordWithExpiredTokenDeletesRowAndIsRejected() {
        User user = userWithId(1L);
        PasswordResetToken row = resetTokenRow(user, "123456", LocalDateTime.now().minusSeconds(1));
        row.setResetTokenHash(tokenHasher.hash("expired-reset-token"));
        row.setVerifiedAt(LocalDateTime.now().minusMinutes(20));
        when(passwordResetTokenRepository.findByResetTokenHash(tokenHasher.hash("expired-reset-token")))
                .thenReturn(Optional.of(row));

        assertThatThrownBy(() -> authService.resetPassword(
                new ResetPasswordRequest("expired-reset-token", "NewPassword1")))
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("PASSWORD_RESET_TOKEN_EXPIRED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                });
        verify(passwordResetTokenRepository).delete(row);
        verify(userService, never()).resetPassword(any(), any());
        verify(refreshTokenRepository, never()).deleteByUserId(any());
    }
}
