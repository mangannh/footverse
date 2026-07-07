package com.footverse.auth.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.auth.entity.RefreshToken;

/**
 * Data access for {@link RefreshToken} rows. Registration and login persist new rows; refresh
 * rotation looks a row up by its SHA-256 hash and deletes it via the inherited {@code delete}.
 */
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    /**
     * Finds a refresh-token row by its stored SHA-256 hash.
     *
     * @param tokenHash the SHA-256 hash of the raw refresh token
     * @return the matching row, if any
     */
    Optional<RefreshToken> findByTokenHash(String tokenHash);
}
