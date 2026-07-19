package com.footverse.order.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.HexFormat;
import java.util.Map;
import java.util.SortedMap;
import java.util.TreeMap;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * VNPay's sorted-parameter canonicalization and HMAC-SHA512 signature scheme (Sprint 13 Task 08,
 * business-rules → Payment), implemented exactly as VNPay's published integration guide: parameters
 * are sorted by key, each non-empty value is URL-encoded ({@code US-ASCII}), the pairs are joined as
 * {@code key=value} with {@code &}, and the result is HMAC-SHA512-signed with the merchant's hash
 * secret to a lowercase hex digest.
 *
 * <p>A pure, stateless utility — not a Spring bean (the {@code common/util/TokenHasher} precedent,
 * kept in the {@code order} module because the canonicalization is VNPay-specific). It makes no
 * network call and holds no state, so the whole signature scheme is unit-testable offline, without
 * ever contacting the sandbox.</p>
 */
final class VnpaySigner {

    private static final String HMAC_ALGORITHM = "HmacSHA512";
    private static final String SECURE_HASH_PARAM = "vnp_SecureHash";

    private VnpaySigner() {
    }

    /**
     * Signs the given parameters with the merchant's hash secret.
     *
     * @param params the parameters to sign (a {@code vnp_SecureHash} entry, if present, is included
     *               as-is — the caller is responsible for excluding it before signing)
     * @param secret the merchant's VNPay hash secret
     * @return the lowercase hex HMAC-SHA512 digest of the canonicalized parameters
     */
    static String sign(Map<String, String> params, String secret) {
        return hmacSha512(secret, canonicalize(params));
    }

    /**
     * Verifies that {@code params} carries a {@code vnp_SecureHash} matching the signature of every
     * other parameter, signed with the merchant's hash secret.
     *
     * @param params the received parameters, including {@code vnp_SecureHash}
     * @param secret the merchant's VNPay hash secret
     * @return {@code true} when the signature matches; {@code false} when it is missing, tampered,
     *         or was computed over a different parameter set (one added, removed, or altered)
     */
    static boolean verify(Map<String, String> params, String secret) {
        String providedHash = params.get(SECURE_HASH_PARAM);
        if (providedHash == null || providedHash.isEmpty()) {
            return false;
        }
        SortedMap<String, String> signedParams = new TreeMap<>(params);
        signedParams.remove(SECURE_HASH_PARAM);
        return sign(signedParams, secret).equalsIgnoreCase(providedHash);
    }

    private static String canonicalize(Map<String, String> params) {
        SortedMap<String, String> sorted = new TreeMap<>(params);
        StringBuilder hashData = new StringBuilder();
        boolean first = true;
        for (Map.Entry<String, String> entry : sorted.entrySet()) {
            String value = entry.getValue();
            if (value == null || value.isEmpty()) {
                continue;
            }
            if (!first) {
                hashData.append('&');
            }
            hashData.append(entry.getKey()).append('=').append(urlEncode(value));
            first = false;
        }
        return hashData.toString();
    }

    private static String urlEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.US_ASCII);
    }

    private static String hmacSha512(String secret, String data) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM));
            byte[] result = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(result);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("HmacSHA512 algorithm not available", e);
        }
    }
}
