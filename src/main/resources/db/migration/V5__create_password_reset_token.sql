-- Sprint 13 Task 04: password-reset one-time-code persistence (database-spec §10.16). Mirrors
-- refresh_token (V1) in shape, naming, charset, and cascade policy -- the raw one-time code and
-- the raw reset token are never stored, only their SHA-256 hashes. One row per in-progress reset
-- attempt: reset_token_hash and verified_at live on the same row as the OTP (one attempt, one
-- row, one lifecycle -- a second table for the verified stage would double the cleanup rules for
-- nothing). No back-fill is needed -- this is a new table, not a column added to an existing one.

CREATE TABLE password_reset_token (
    id               BIGINT       NOT NULL AUTO_INCREMENT,
    user_id          BIGINT       NOT NULL,
    otp_hash         VARCHAR(64)  NOT NULL,
    reset_token_hash VARCHAR(64)  NULL,
    expires_at       DATETIME(6)  NOT NULL,
    attempt_count    INT          NOT NULL DEFAULT 0,
    verified_at      DATETIME(6)  NULL,
    created_at       DATETIME(6)  NOT NULL,
    updated_at       DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_password_reset_token_reset_token_hash (reset_token_hash),
    KEY idx_password_reset_token_user_id (user_id),
    CONSTRAINT fk_password_reset_token_user FOREIGN KEY (user_id) REFERENCES user (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
