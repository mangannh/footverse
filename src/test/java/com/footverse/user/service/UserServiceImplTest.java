package com.footverse.user.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import com.footverse.common.security.CurrentUserProvider;
import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.Role;
import com.footverse.user.entity.User;
import com.footverse.user.mapper.UserMapper;
import com.footverse.user.repository.UserRepository;

/**
 * Unit tests for {@link UserServiceImpl}.
 */
@ExtendWith(MockitoExtension.class)
class UserServiceImplTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserMapper userMapper;

    @Mock
    private CurrentUserProvider currentUserProvider;

    private UserServiceImpl userService;

    @BeforeEach
    void setUp() {
        userService = new UserServiceImpl(userRepository, userMapper, currentUserProvider);
    }

    /**
     * The current-user lookup resolves the caller via {@link CurrentUserProvider} and maps that
     * exact user to its response — it never takes any argument.
     */
    @Test
    void getCurrentUserMapsTheAuthenticatedCaller() {
        User caller = new User();
        caller.setId(7L);
        caller.setEmail("caller@example.com");
        UserResponse response = new UserResponse(7L, "caller@example.com", "Caller", "0912345678",
                null, Role.CUSTOMER, true, LocalDateTime.now(), LocalDateTime.now());
        when(currentUserProvider.getCurrentUser()).thenReturn(caller);
        when(userMapper.toResponse(caller)).thenReturn(response);

        assertThat(userService.getCurrentUser()).isEqualTo(response);
        verify(currentUserProvider).getCurrentUser();
        verify(userMapper).toResponse(caller);
    }

    /**
     * A created user is a persisted, enabled CUSTOMER carrying the given fields.
     */
    @Test
    void createUserPersistsEnabledCustomer() {
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        userService.createUser("user@example.com", "encoded-password", "Test User", "0912345678");

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());
        User persisted = captor.getValue();
        assertThat(persisted.getEmail()).isEqualTo("user@example.com");
        assertThat(persisted.getPassword()).isEqualTo("encoded-password");
        assertThat(persisted.getFullName()).isEqualTo("Test User");
        assertThat(persisted.getPhone()).isEqualTo("0912345678");
        assertThat(persisted.getRole()).isEqualTo(Role.CUSTOMER);
        assertThat(persisted.isEnabled()).isTrue();
    }

    /**
     * Existence checks delegate to the repository.
     */
    @Test
    void existenceChecksDelegateToRepository() {
        when(userRepository.existsByEmail("user@example.com")).thenReturn(true);
        when(userRepository.existsByPhone("0912345678")).thenReturn(false);

        assertThat(userService.existsByEmail("user@example.com")).isTrue();
        assertThat(userService.existsByPhone("0912345678")).isFalse();
    }
}
