package com.footverse.auth.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.auth.entity.RefreshToken;

/**
 * Data access for {@link RefreshToken} rows. Registration only persists new rows; lookup and
 * rotation methods are added by later tasks.
 */
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {
}
