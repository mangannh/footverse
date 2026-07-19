package com.footverse.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.ForgotPasswordRequest;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.PasswordResetTokenResponse;
import com.footverse.auth.dto.ResetPasswordRequest;
import com.footverse.auth.dto.VerifyResetOtpRequest;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.auth.service.AuthService;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.mail.EmailSender;
import com.footverse.common.util.TokenHasher;
import com.footverse.support.AuthFixtures;

/**
 * End-to-end password-reset flow against the real database (sprint-13-plan Task 05):
 * {@code register → forgot-password → verify-reset-otp → reset-password}, then proves the reset's
 * two side effects that pure-Mockito tests cannot: the new password logs in while the old one is
 * rejected, and a refresh token minted before the reset is revoked with it.
 *
 * <p>{@link EmailSender} is replaced with a {@code @MockitoBean} purely to capture the one-time
 * code out of the email body — this test never sends real mail regardless, since the default
 * {@code LoggingEmailSender} never touches a mail server either.</p>
 */
@SpringBootTest
@Transactional
class AuthForgotPasswordFlowIntegrationTest {

    private static final String EMAIL = "forgot-password-flow@example.com";
    private static final String PHONE = "0900000095";
    private static final String NEW_PASSWORD = "NewPassword1";

    private final AuthService authService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final TokenHasher tokenHasher;

    @MockitoBean
    private EmailSender emailSender;

    AuthForgotPasswordFlowIntegrationTest(@Autowired AuthService authService,
                                          @Autowired RefreshTokenRepository refreshTokenRepository,
                                          @Autowired TokenHasher tokenHasher) {
        this.authService = authService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.tokenHasher = tokenHasher;
    }

    private boolean rowExistsFor(String rawRefreshToken) {
        return refreshTokenRepository.findByTokenHash(tokenHasher.hash(rawRefreshToken)).isPresent();
    }

    private String capturedOtp() {
        ArgumentCaptor<String> bodyCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailSender).send(eq(EMAIL), any(), bodyCaptor.capture());
        Matcher matcher = Pattern.compile("\\d{6}").matcher(bodyCaptor.getValue());
        assertThat(matcher.find()).isTrue();
        return matcher.group();
    }

    /**
     * The full reset flow: the emailed code verifies into a reset token, the reset token sets a new
     * password, the account can log in with it, the old password no longer works, and the refresh
     * token minted before the reset is revoked along with every other session.
     */
    @Test
    void forgotPasswordVerifyResetOtpAndResetPasswordFlow() {
        AuthResponse registered = authService.register(AuthFixtures.registerRequest(EMAIL, PHONE, "Reset Flow"));
        assertThat(rowExistsFor(registered.refreshToken())).isTrue();

        authService.forgotPassword(new ForgotPasswordRequest(EMAIL));
        String otp = capturedOtp();

        PasswordResetTokenResponse verified = authService.verifyResetOtp(
                new VerifyResetOtpRequest(EMAIL, otp));
        assertThat(verified.resetToken()).isNotBlank();

        authService.resetPassword(new ResetPasswordRequest(verified.resetToken(), NEW_PASSWORD));

        AuthResponse loggedInWithNewPassword = authService.login(new LoginRequest(EMAIL, NEW_PASSWORD));
        assertThat(loggedInWithNewPassword.accessToken()).isNotBlank();

        assertThatThrownBy(() -> authService.login(AuthFixtures.loginRequest(EMAIL)))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("INVALID_CREDENTIALS"));

        assertThatThrownBy(() -> authService.refresh(AuthFixtures.refreshRequest(registered.refreshToken())))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("REFRESH_TOKEN_INVALID"));
    }
}
