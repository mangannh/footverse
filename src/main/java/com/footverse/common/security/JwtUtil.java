package com.footverse.common.security;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

import javax.crypto.SecretKey;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

/**
 * Creates and validates stateless HS256 access tokens.
 *
 * <p>The secret and access-token time-to-live are read from configuration
 * ({@code footverse.jwt.secret}, {@code footverse.jwt.access-token-ttl-seconds}; default TTL
 * 15 minutes). Tokens carry only the standard {@code sub}, {@code iat} and {@code exp} claims
 * — no custom claims. This class performs token operations only and holds no business
 * logic.</p>
 */
@Component
public class JwtUtil {

    private final SecretKey secretKey;
    private final long accessTokenTtlSeconds;

    /**
     * Creates the utility from externalized configuration.
     *
     * @param secret                the HMAC signing secret (at least 256 bits)
     * @param accessTokenTtlSeconds the access-token lifetime in seconds
     */
    public JwtUtil(@Value("${footverse.jwt.secret}") String secret,
                   @Value("${footverse.jwt.access-token-ttl-seconds}") long accessTokenTtlSeconds) {
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenTtlSeconds = accessTokenTtlSeconds;
    }

    /**
     * Creates a signed access token for the given subject.
     *
     * @param subject the token subject (the authenticated principal identifier)
     * @return the compact, signed JWT
     */
    public String createAccessToken(String subject) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(subject)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(accessTokenTtlSeconds)))
                .signWith(secretKey)
                .compact();
    }

    /**
     * Returns the subject of a valid token.
     *
     * @param token the compact JWT
     * @return the {@code sub} claim
     * @throws JwtException if the token is malformed, tampered with, or expired
     */
    public String getSubject(String token) {
        return parseClaims(token).getSubject();
    }

    /**
     * Returns the expiration timestamp of a valid token.
     *
     * @param token the compact JWT
     * @return the {@code exp} claim
     * @throws JwtException if the token is malformed, tampered with, or expired
     */
    public Date getExpiration(String token) {
        return parseClaims(token).getExpiration();
    }

    /**
     * Checks whether a token is expired.
     *
     * @param token the compact JWT
     * @return {@code true} if the token has expired
     */
    public boolean isExpired(String token) {
        try {
            return parseClaims(token).getExpiration().before(new Date());
        } catch (ExpiredJwtException e) {
            return true;
        }
    }

    /**
     * Validates a token's signature, format and expiration.
     *
     * @param token the compact JWT
     * @return {@code true} if the token is well-formed, correctly signed and not expired
     */
    public boolean isValid(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    private Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(secretKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
