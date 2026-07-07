package com.footverse.common.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import java.util.Collections;
import java.util.Optional;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import com.footverse.common.exception.BusinessException;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

/**
 * Unit tests for {@link CurrentUserProvider}: it resolves the authenticated principal to a
 * {@link User} and rejects missing/unresolvable authentication with the enveloped 401.
 */
@ExtendWith(MockitoExtension.class)
class CurrentUserProviderTest {

    @Mock
    private UserRepository userRepository;

    private CurrentUserProvider currentUserProvider;

    @BeforeEach
    void setUp() {
        currentUserProvider = new CurrentUserProvider(userRepository);
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    private void authenticateAs(String email) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(email, null, Collections.emptyList()));
    }

    /**
     * The authenticated principal is resolved to its {@link User} via the repository.
     */
    @Test
    void resolvesAuthenticatedUser() {
        User user = new User();
        user.setId(1L);
        user.setEmail("caller@example.com");
        authenticateAs("caller@example.com");
        when(userRepository.findByEmail("caller@example.com")).thenReturn(Optional.of(user));

        assertThat(currentUserProvider.getCurrentUser()).isEqualTo(user);
    }

    /**
     * With no authentication in the context, a 401 {@code UNAUTHORIZED} is raised.
     */
    @Test
    void rejectsWhenNoAuthentication() {
        assertThatThrownBy(currentUserProvider::getCurrentUser)
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("UNAUTHORIZED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
    }

    /**
     * When the authenticated principal no longer resolves to a user, a 401 is raised.
     */
    @Test
    void rejectsWhenPrincipalDoesNotResolve() {
        authenticateAs("ghost@example.com");
        when(userRepository.findByEmail("ghost@example.com")).thenReturn(Optional.empty());

        assertThatThrownBy(currentUserProvider::getCurrentUser)
                .isInstanceOfSatisfying(BusinessException.class, ex -> {
                    assertThat(ex.getErrorCode()).isEqualTo("UNAUTHORIZED");
                    assertThat(ex.getHttpStatus()).isEqualTo(HttpStatus.UNAUTHORIZED);
                });
    }
}
