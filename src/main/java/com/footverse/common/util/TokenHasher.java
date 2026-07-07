package com.footverse.common.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

import org.springframework.stereotype.Component;

/**
 * Hashes opaque tokens with SHA-256 for server-side storage.
 *
 * <p>Deterministic and stateless: the same input always yields the same 64-character lowercase
 * hex digest. Used to store only the hash of refresh tokens (never the raw value).</p>
 */
@Component
public class TokenHasher {

    /**
     * Returns the SHA-256 hex digest of the given token.
     *
     * @param token the raw token
     * @return the 64-character lowercase hex digest
     */
    public String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hashed);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 algorithm not available", e);
        }
    }
}
