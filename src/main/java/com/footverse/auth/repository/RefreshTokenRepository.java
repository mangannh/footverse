package com.footverse.auth.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.auth.entity.RefreshToken;

/**
 * Data access for {@link RefreshToken} rows. Registration and login persist new rows; refresh
 * rotation looks a row up by its SHA-256 hash and deletes it via the inherited {@code delete}; a
 * successful password reset (Sprint 13 Task 05) deletes every row for the account at once, ending
 * all of its sessions.
 */
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    /**
     * Finds a refresh-token row by its stored SHA-256 hash.
     *
     * @param tokenHash the SHA-256 hash of the raw refresh token
     * @return the matching row, if any
     */
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /**
     * Deletes every refresh-token row owned by the given user — used by a successful password
     * reset to revoke all of the account's existing sessions at once.
     *
     * @param userId the owning user id
     */
    void deleteByUserId(Long userId);
}
