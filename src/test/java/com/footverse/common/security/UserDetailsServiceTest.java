package com.footverse.common.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import com.footverse.user.entity.Role;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

/**
 * Unit tests for {@link UserDetailsServiceImpl} email lookup, disabled handling and authority
 * mapping.
 */
@ExtendWith(MockitoExtension.class)
class UserDetailsServiceTest {

    private static final String EMAIL = "user@example.com";

    @Mock
    private UserRepository userRepository;

    private UserDetailsServiceImpl userDetailsService;

    @BeforeEach
    void setUp() {
        userDetailsService = new UserDetailsServiceImpl(userRepository);
    }

    private User buildUser(Role role, boolean enabled) {
        User user = new User();
        user.setEmail(EMAIL);
        user.setPassword("$2a$10$hashedpassword");
        user.setFullName("Test User");
        user.setPhone("0912345678");
        user.setRole(role);
        user.setEnabled(enabled);
        return user;
    }

    /**
     * An enabled user is loaded by email and mapped to authenticated user details.
     */
    @Test
    void loadsEnabledUserByEmail() {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(buildUser(Role.CUSTOMER, true)));

        UserDetails details = userDetailsService.loadUserByUsername(EMAIL);

        assertThat(details.getUsername()).isEqualTo(EMAIL);
        assertThat(details.getPassword()).isEqualTo("$2a$10$hashedpassword");
        assertThat(details.getAuthorities()).extracting(GrantedAuthority::getAuthority)
                .containsExactly("ROLE_CUSTOMER");
    }

    /**
     * An unknown email raises {@link UsernameNotFoundException}.
     */
    @Test
    void throwsWhenEmailNotFound() {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userDetailsService.loadUserByUsername(EMAIL))
                .isInstanceOf(UsernameNotFoundException.class);
    }

    /**
     * A disabled account is rejected with {@link DisabledException}.
     */
    @Test
    void rejectsDisabledUser() {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(buildUser(Role.CUSTOMER, false)));

        assertThatThrownBy(() -> userDetailsService.loadUserByUsername(EMAIL))
                .isInstanceOf(DisabledException.class);
    }

    /**
     * The {@code ADMIN} role maps to the {@code ROLE_ADMIN} authority.
     */
    @Test
    void mapsAdminRoleToAuthority() {
        when(userRepository.findByEmail(EMAIL)).thenReturn(Optional.of(buildUser(Role.ADMIN, true)));

        UserDetails details = userDetailsService.loadUserByUsername(EMAIL);

        assertThat(details.getAuthorities()).extracting(GrantedAuthority::getAuthority)
                .containsExactly("ROLE_ADMIN");
    }
}
