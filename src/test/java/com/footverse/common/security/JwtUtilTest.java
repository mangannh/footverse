package com.footverse.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Date;

import org.junit.jupiter.api.Test;

/**
 * Unit tests for {@link JwtUtil} token creation, validation and expiry handling.
 */
class JwtUtilTest {

    private static final String SECRET = "test-secret-key-that-is-at-least-32-bytes-long";
    private static final String OTHER_SECRET = "another-test-secret-key-at-least-32-bytes-xx";
    private static final String SUBJECT = "user@example.com";

    private final JwtUtil jwtUtil = new JwtUtil(SECRET, 900);

    /**
     * A freshly created token validates and exposes its subject and future expiry.
     */
    @Test
    void validTokenExposesSubjectAndIsNotExpired() {
        String token = jwtUtil.createAccessToken(SUBJECT);

        assertThat(jwtUtil.isValid(token)).isTrue();
        assertThat(jwtUtil.getSubject(token)).isEqualTo(SUBJECT);
        assertThat(jwtUtil.isExpired(token)).isFalse();
        assertThat(jwtUtil.getExpiration(token)).isAfter(new Date());
    }

    /**
     * A token whose expiry is in the past is invalid and reported as expired.
     */
    @Test
    void expiredTokenIsInvalid() {
        String expiredToken = new JwtUtil(SECRET, -60).createAccessToken(SUBJECT);

        assertThat(jwtUtil.isValid(expiredToken)).isFalse();
        assertThat(jwtUtil.isExpired(expiredToken)).isTrue();
    }

    /**
     * A token signed with a different secret fails signature verification.
     */
    @Test
    void tamperedSignatureIsInvalid() {
        String otherToken = new JwtUtil(OTHER_SECRET, 900).createAccessToken(SUBJECT);

        assertThat(jwtUtil.isValid(otherToken)).isFalse();
    }

    /**
     * A structurally malformed token is invalid.
     */
    @Test
    void malformedTokenIsInvalid() {
        assertThat(jwtUtil.isValid("not-a-jwt")).isFalse();
    }
}
