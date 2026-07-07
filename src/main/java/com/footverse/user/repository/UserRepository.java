package com.footverse.user.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.user.entity.User;

/**
 * Data access for {@link User} accounts.
 */
public interface UserRepository extends JpaRepository<User, Long> {

    /**
     * Finds a user by email.
     *
     * @param email the email to look up
     * @return the matching user, if any
     */
    Optional<User> findByEmail(String email);

    /**
     * Checks whether a user with the given email exists.
     *
     * @param email the email to check
     * @return {@code true} if a user has the email
     */
    boolean existsByEmail(String email);

    /**
     * Checks whether a user with the given phone exists.
     *
     * @param phone the phone to check
     * @return {@code true} if a user has the phone
     */
    boolean existsByPhone(String phone);
}
