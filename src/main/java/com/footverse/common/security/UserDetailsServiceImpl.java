package com.footverse.common.security;

import org.springframework.security.authentication.DisabledException;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

/**
 * Loads users for Spring Security authentication.
 *
 * <p>This infrastructure component intentionally depends on the {@code user} module
 * (architecture-spec §7). Its sole responsibility is to load a {@link User} by email and map
 * it to a {@link UserDetails}; it performs no password checking, token handling, or business
 * logic. Unknown emails raise {@link UsernameNotFoundException} and disabled accounts raise
 * {@link DisabledException}.</p>
 */
@Service
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {

    private static final String ROLE_PREFIX = "ROLE_";

    private final UserRepository userRepository;

    /**
     * Loads the user with the given email as Spring Security {@link UserDetails}.
     *
     * @param email the account email
     * @return the mapped user details
     * @throws UsernameNotFoundException if no user has the email
     * @throws DisabledException         if the account is disabled
     */
    @Override
    public UserDetails loadUserByUsername(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        if (!user.isEnabled()) {
            throw new DisabledException("User account is disabled");
        }
        return org.springframework.security.core.userdetails.User.builder()
                .username(user.getEmail())
                .password(user.getPassword())
                .authorities(new SimpleGrantedAuthority(ROLE_PREFIX + user.getRole().name()))
                .build();
    }
}
