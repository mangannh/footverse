package com.footverse.auth.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.auth.entity.PasswordResetToken;

/**
 * Data access for {@link PasswordResetToken} rows (Sprint 13 Task 04). The forgot-password flow
 * (Task 06) looks a row up by its owning user before starting a new attempt, and by its reset-token
 * hash while verifying and consuming one; the cascade on {@code user} deletion is enforced by the
 * database, not here.
 */
public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {

    /**
     * Finds the in-progress reset attempt for a user, if any. By design there is at most one row
     * per user at a time — a new request replaces any existing row before creating another.
     *
     * @param userId the owning user id
     * @return the matching row, if any
     */
    Optional<PasswordResetToken> findByUserId(Long userId);

    /**
     * Finds a reset attempt by its stored SHA-256 reset-token hash, once the one-time code has been
     * verified.
     *
     * @param resetTokenHash the SHA-256 hash of the raw reset token
     * @return the matching row, if any
     */
    Optional<PasswordResetToken> findByResetTokenHash(String resetTokenHash);

    /**
     * Deletes the in-progress reset attempt for a user, if any — used to clear a stale row before a
     * new {@code POST /auth/forgot-password} request starts a fresh one.
     *
     * @param userId the owning user id
     */
    void deleteByUserId(Long userId);
}
