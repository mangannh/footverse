package com.footverse.common.security;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import com.footverse.common.exception.BusinessException;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import lombok.RequiredArgsConstructor;

/**
 * Single, canonical access point to the authenticated user (architecture-spec §12,
 * security-spec §3).
 *
 * <p>This is the only place in the codebase that reads the {@link SecurityContextHolder};
 * scattered direct access is forbidden. Services obtain the acting user through it for ownership
 * checks and for stamping user-scoped data. As security infrastructure it loads the user via
 * {@link UserRepository} — the same intentional infrastructure → feature dependency that
 * {@code UserDetailsServiceImpl} uses (architecture-spec §7). Resolving through the repository
 * (rather than {@code UserService}) also keeps the bean graph acyclic, since {@code UserService}
 * itself reads the current user through this provider.</p>
 */
@Component
@RequiredArgsConstructor
public class CurrentUserProvider {

    private final UserRepository userRepository;

    /**
     * Returns the currently authenticated user resolved from the security context.
     *
     * @return the authenticated {@link User}
     * @throws BusinessException HTTP {@code 401} when there is no authenticated user in the
     *                           context, or the authenticated principal no longer resolves to a
     *                           user
     */
    public User getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            throw unauthenticated();
        }
        return userRepository.findByEmail(authentication.getName())
                .orElseThrow(this::unauthenticated);
    }

    private BusinessException unauthenticated() {
        return new BusinessException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Authentication required");
    }
}
