package com.footverse.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDateTime;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import com.footverse.auth.dto.RefreshTokenRequest;
import com.footverse.auth.entity.RefreshToken;
import com.footverse.auth.repository.RefreshTokenRepository;
import com.footverse.auth.service.AuthService;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.util.TokenHasher;
import com.footverse.user.entity.Role;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

/**
 * Verifies canonical flow step 5 durably: presenting an expired refresh token deletes its row
 * from the database (lazy cleanup) and returns {@code REFRESH_TOKEN_EXPIRED}.
 *
 * <p>Intentionally <strong>not</strong> {@code @Transactional}: {@code AuthService.refresh} must
 * open and commit its own transaction so the deletion is proven to survive after the request,
 * rather than being visible only inside a test transaction that later rolls back. Fixtures are
 * removed in {@link #cleanUp()} so no state leaks between runs.</p>
 */
@SpringBootTest
class AuthRefreshExpiredCleanupIntegrationTest {

    private static final String EMAIL = "expired-refresh@example.com";
    private static final String PHONE = "0900000016";
    private static final String RAW_TOKEN = "expired-raw-refresh-token-value";

    private final AuthService authService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRepository userRepository;
    private final TokenHasher tokenHasher;

    AuthRefreshExpiredCleanupIntegrationTest(@Autowired AuthService authService,
                                             @Autowired RefreshTokenRepository refreshTokenRepository,
                                             @Autowired UserRepository userRepository,
                                             @Autowired TokenHasher tokenHasher) {
        this.authService = authService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.userRepository = userRepository;
        this.tokenHasher = tokenHasher;
    }

    @AfterEach
    void cleanUp() {
        refreshTokenRepository.findByTokenHash(tokenHasher.hash(RAW_TOKEN))
                .ifPresent(refreshTokenRepository::delete);
        userRepository.findByEmail(EMAIL).ifPresent(userRepository::delete);
    }

    /**
     * An expired refresh token is physically removed from the database and rejected with
     * {@code REFRESH_TOKEN_EXPIRED}; the delete is committed, so a follow-up lookup finds nothing.
     */
    @Test
    void expiredRefreshTokenIsDeletedFromDatabase() {
        User user = new User();
        user.setEmail(EMAIL);
        user.setPassword("irrelevant-for-this-path");
        user.setFullName("Expired User");
        user.setPhone(PHONE);
        user.setRole(Role.CUSTOMER);
        user.setEnabled(true);
        userRepository.save(user);

        RefreshToken expiredRow = new RefreshToken();
        expiredRow.setUser(user);
        expiredRow.setTokenHash(tokenHasher.hash(RAW_TOKEN));
        expiredRow.setExpiresAt(LocalDateTime.now().minusDays(1));
        refreshTokenRepository.save(expiredRow);

        assertThatThrownBy(() -> authService.refresh(new RefreshTokenRequest(RAW_TOKEN)))
                .isInstanceOfSatisfying(BusinessException.class, ex ->
                        assertThat(ex.getErrorCode()).isEqualTo("REFRESH_TOKEN_EXPIRED"));

        assertThat(refreshTokenRepository.findByTokenHash(tokenHasher.hash(RAW_TOKEN))).isEmpty();
    }
}
