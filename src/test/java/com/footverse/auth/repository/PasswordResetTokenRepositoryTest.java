package com.footverse.auth.repository;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;

import com.footverse.auth.entity.PasswordResetToken;
import com.footverse.common.config.JpaAuditingConfig;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.User;
import com.footverse.user.repository.UserRepository;

import jakarta.persistence.EntityManager;

/**
 * {@code @DataJpaTest} for {@link PasswordResetTokenRepository} (testing-guidelines §Repository
 * Testing, sprint-13-plan Task 04): lookup by owning user, lookup by the verified reset-token
 * hash, and the {@code ON DELETE CASCADE} behaviour observed through ordinary repository calls
 * (the {@code PasswordResetTokenMigrationTest} proves the same cascade at the schema level).
 * Runs against the real configured MySQL datasource (no embedded test database in this project,
 * mirroring {@code OrderRepositoryTest} / sprint-12-plan Task 01). {@link JpaAuditingConfig} is
 * imported explicitly because {@code @DataJpaTest}'s slice scan does not pick up plain
 * {@code @Configuration} beans, and the seeded rows rely on {@code @CreatedDate} being
 * auto-populated.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig.class)
class PasswordResetTokenRepositoryTest {

    private static final String EMAIL = "password-reset-repo-test@example.com";
    private static final String PHONE = "0900000093";

    @Autowired
    private PasswordResetTokenRepository passwordResetTokenRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EntityManager entityManager;

    private PasswordResetToken token(User user, String resetTokenHash) {
        PasswordResetToken token = new PasswordResetToken();
        token.setUser(user);
        token.setOtpHash("a".repeat(64));
        token.setResetTokenHash(resetTokenHash);
        token.setExpiresAt(LocalDateTime.now().plusMinutes(10));
        return token;
    }

    /**
     * {@code findByUserId} returns the in-progress reset attempt for that user.
     */
    @Test
    void findByUserIdReturnsTheAttemptForThatUser() {
        User user = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        PasswordResetToken saved = passwordResetTokenRepository.save(token(user, null));

        Optional<PasswordResetToken> found = passwordResetTokenRepository.findByUserId(user.getId());

        assertThat(found).isPresent();
        assertThat(found.orElseThrow().getId()).isEqualTo(saved.getId());
    }

    /**
     * {@code findByUserId} returns empty for a user with no in-progress attempt.
     */
    @Test
    void findByUserIdReturnsEmptyWhenNoAttemptExists() {
        User user = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));

        assertThat(passwordResetTokenRepository.findByUserId(user.getId())).isEmpty();
    }

    /**
     * {@code findByResetTokenHash} returns the attempt whose one-time code has already been
     * verified — the hash is set only once verification succeeds.
     */
    @Test
    void findByResetTokenHashReturnsTheVerifiedAttempt() {
        User user = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        String resetTokenHash = "b".repeat(64);
        PasswordResetToken saved = passwordResetTokenRepository.save(token(user, resetTokenHash));

        Optional<PasswordResetToken> found =
                passwordResetTokenRepository.findByResetTokenHash(resetTokenHash);

        assertThat(found).isPresent();
        assertThat(found.orElseThrow().getId()).isEqualTo(saved.getId());
    }

    /**
     * {@code findByResetTokenHash} returns empty for an unknown hash.
     */
    @Test
    void findByResetTokenHashReturnsEmptyForAnUnknownHash() {
        assertThat(passwordResetTokenRepository.findByResetTokenHash("c".repeat(64))).isEmpty();
    }

    /**
     * {@code deleteByUserId} clears the stale row before a fresh request starts a new one.
     */
    @Test
    void deleteByUserIdRemovesTheExistingAttempt() {
        User user = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        passwordResetTokenRepository.save(token(user, null));

        passwordResetTokenRepository.deleteByUserId(user.getId());

        assertThat(passwordResetTokenRepository.findByUserId(user.getId())).isEmpty();
    }

    /**
     * Deleting the owning user cascades to the reset-token row — observed here through ordinary
     * repository calls (the migration test proves the same at the schema/FK level).
     */
    @Test
    void deletingTheOwningUserCascadesToTheResetTokenRow() {
        User user = userRepository.save(AuthFixtures.customer(EMAIL, PHONE));
        PasswordResetToken saved = passwordResetTokenRepository.saveAndFlush(token(user, "d".repeat(64)));
        Long userId = user.getId();
        // Clear the persistence context so the delete below does not trip over the still-managed
        // `user`/`token` instances from the setup above (the OrderItemCostSnapshotMigrationTest
        // precedent).
        entityManager.clear();

        userRepository.deleteById(userId);
        userRepository.flush();

        assertThat(passwordResetTokenRepository.findById(saved.getId())).isEmpty();
    }
}
