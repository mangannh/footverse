package com.footverse.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;

import com.footverse.auth.entity.PasswordResetToken;
import com.footverse.auth.repository.PasswordResetTokenRepository;
import com.footverse.common.config.JpaAuditingConfig;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;

/**
 * {@code @DataJpaTest} for the {@code V5__create_password_reset_token.sql} migration
 * (testing-guidelines §Repository Testing, sprint-13-plan Task 04): the table exists with the
 * frozen columns/keys, and the {@code ON DELETE CASCADE} foreign key to {@code user} actually
 * removes rows. Runs against the real configured MySQL datasource (no embedded test database in
 * this project, mirroring {@code OrderItemCostSnapshotMigrationTest} / sprint-12-plan Task 02).
 * {@link JpaAuditingConfig} is imported explicitly because {@code @DataJpaTest}'s slice scan does
 * not pick up plain {@code @Configuration} beans, and the seeded rows rely on
 * {@code @CreatedDate} being auto-populated.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig.class)
class PasswordResetTokenMigrationTest {

    private static final String EMAIL = "password-reset-migration-test@example.com";
    private static final String PHONE = "0900000094";

    @Autowired
    private EntityManager entityManager;

    @Autowired
    private PasswordResetTokenRepository passwordResetTokenRepository;

    @Autowired
    private UserRepository userRepository;

    /**
     * The {@code password_reset_token} table exists with the frozen columns and their nullability
     * (database-spec §10.16) — read directly from {@code information_schema}, independent of the
     * JPA entity mapping, so a stray annotation on the entity cannot mask a schema mismatch.
     */
    @Test
    void tableExistsWithFrozenColumnsAndNullability() {
        Query query = entityManager.createNativeQuery(
                "SELECT COLUMN_NAME, IS_NULLABLE FROM information_schema.COLUMNS "
                        + "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'password_reset_token' "
                        + "ORDER BY ORDINAL_POSITION");

        @SuppressWarnings("unchecked")
        List<Object[]> rows = query.getResultList();

        assertThat(rows).extracting(row -> row[0])
                .containsExactly("id", "user_id", "otp_hash", "reset_token_hash", "expires_at",
                        "attempt_count", "verified_at", "created_at", "updated_at");

        assertThat(nullability(rows, "user_id")).isEqualTo("NO");
        assertThat(nullability(rows, "otp_hash")).isEqualTo("NO");
        assertThat(nullability(rows, "reset_token_hash")).isEqualTo("YES");
        assertThat(nullability(rows, "expires_at")).isEqualTo("NO");
        assertThat(nullability(rows, "attempt_count")).isEqualTo("NO");
        assertThat(nullability(rows, "verified_at")).isEqualTo("YES");
    }

    /**
     * {@code reset_token_hash} carries a unique key — a duplicate value is rejected by the
     * database, not merely by application code.
     */
    @Test
    void resetTokenHashHasAUniqueKey() {
        Query query = entityManager.createNativeQuery(
                "SELECT COUNT(*) FROM information_schema.STATISTICS "
                        + "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'password_reset_token' "
                        + "AND INDEX_NAME = 'uk_password_reset_token_reset_token_hash' "
                        + "AND NON_UNIQUE = 0");

        Number count = (Number) query.getSingleResult();

        assertThat(count.intValue()).isEqualTo(1);
    }

    /**
     * The {@code fk_password_reset_token_user} foreign key is {@code ON DELETE CASCADE}: deleting
     * the owning user removes the reset-token row with it, exactly like {@code refresh_token}.
     */
    @Test
    void deletingTheOwningUserCascadesToTheResetTokenRow() {
        User user = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        PasswordResetToken token = new PasswordResetToken();
        token.setUser(user);
        token.setOtpHash("a".repeat(64));
        token.setExpiresAt(LocalDateTime.now().plusMinutes(10));
        PasswordResetToken saved = passwordResetTokenRepository.saveAndFlush(token);
        Long userId = user.getId();
        // Clear the persistence context so the delete below does not trip over the still-managed
        // `user`/`token` instances from the setup above (the OrderItemCostSnapshotMigrationTest
        // precedent).
        entityManager.clear();

        userRepository.deleteById(userId);
        userRepository.flush();

        assertThat(passwordResetTokenRepository.findById(saved.getId())).isEmpty();
    }

    private String nullability(List<Object[]> rows, String columnName) {
        return rows.stream()
                .filter(row -> row[0].equals(columnName))
                .map(row -> (String) row[1])
                .findFirst()
                .orElseThrow(() -> new AssertionError("column not found: " + columnName));
    }
}
