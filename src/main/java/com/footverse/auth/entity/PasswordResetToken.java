package com.footverse.auth.entity;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import com.footverse.common.entity.BaseEntity;
import com.footverse.user.entity.User;

import lombok.Getter;
import lombok.Setter;

/**
 * A server-side password-reset attempt (database-spec §10.16, Sprint 13 Task 04). Mirrors
 * {@link RefreshToken} in shape and policy: only the SHA-256 hash of the one-time code and of the
 * opaque reset token are stored — the raw values are never persisted. Maps to the
 * {@code password_reset_token} table.
 *
 * <p>One row covers the whole attempt lifecycle: {@link #otpHash} is set when the code is
 * requested, {@link #resetTokenHash} and {@link #verifiedAt} are set once the code is verified,
 * and the row is deleted on a successful reset or replaced by a new request — there is no separate
 * table for the verified stage.</p>
 */
@Getter
@Setter
@Entity
@Table(name = "password_reset_token")
public class PasswordResetToken extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "otp_hash", nullable = false, length = 64)
    private String otpHash;

    @Column(name = "reset_token_hash", unique = true, length = 64)
    private String resetTokenHash;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "attempt_count", nullable = false)
    private int attemptCount;

    @Column(name = "verified_at")
    private LocalDateTime verifiedAt;
}
