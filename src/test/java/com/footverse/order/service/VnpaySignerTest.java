package com.footverse.order.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.LinkedHashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

/**
 * Unit tests for {@link VnpaySigner} (sprint-13-plan Task 08) against a known parameter set and its
 * independently computed HMAC-SHA512 digest — VNPay's published integration guide specifies the
 * canonicalization (sort by key, URL-encode each non-empty value, join as {@code key=value} with
 * {@code &}) and the HMAC-SHA512 signing step exercised here; {@link #EXPECTED_HASH} was computed
 * offline with an independent HMAC-SHA512 implementation (.NET's
 * {@code System.Security.Cryptography.HMACSHA512}) over the same canonicalized string, so this test
 * does not merely check the signer against itself. No network call is made or needed.
 */
class VnpaySignerTest {

    private static final String SECRET = "SANDBOXSECRETKEY123456";

    /**
     * Independently computed (not by this class or {@link VnpaySigner}) HMAC-SHA512 of
     * {@code vnp_Amount=1000000&vnp_Command=pay&vnp_CreateDate=20240101120000&vnp_CurrCode=VND&
     * vnp_IpAddr=127.0.0.1&vnp_Locale=vn&vnp_OrderInfo=Thanh+toan+don+hang+FV000123&
     * vnp_OrderType=other&vnp_ReturnUrl=https%3A%2F%2Ffootverse.example.com%2Fpayments%2Fvnpay%2Freturn&
     * vnp_TmnCode=DEMO123&vnp_TxnRef=FV000123&vnp_Version=2.1.0}, keyed by {@link #SECRET}.
     */
    private static final String EXPECTED_HASH =
            "eb922eb8b3d8d53e372dad27124185c560194431715a22321ed46e49676c6399085dc98420a6ba"
                    + "13e6dff6d146e201aceec7ae46f549c376577e3686f9f53261";

    private Map<String, String> baseParams() {
        // LinkedHashMap so insertion order is deliberately NOT sorted, proving `sign` sorts by key
        // itself rather than relying on caller order.
        Map<String, String> params = new LinkedHashMap<>();
        params.put("vnp_TxnRef", "FV000123");
        params.put("vnp_Version", "2.1.0");
        params.put("vnp_Command", "pay");
        params.put("vnp_TmnCode", "DEMO123");
        params.put("vnp_Amount", "1000000");
        params.put("vnp_CurrCode", "VND");
        params.put("vnp_OrderInfo", "Thanh toan don hang FV000123");
        params.put("vnp_OrderType", "other");
        params.put("vnp_Locale", "vn");
        params.put("vnp_ReturnUrl", "https://footverse.example.com/payments/vnpay/return");
        params.put("vnp_IpAddr", "127.0.0.1");
        params.put("vnp_CreateDate", "20240101120000");
        return params;
    }

    @Test
    void signProducesTheExpectedHashForTheKnownVector() {
        String hash = VnpaySigner.sign(baseParams(), SECRET);

        assertThat(hash).isEqualToIgnoringCase(EXPECTED_HASH);
    }

    @Test
    void verifyAcceptsAParameterSetSignedWithItsOwnHash() {
        Map<String, String> params = baseParams();
        params.put("vnp_SecureHash", EXPECTED_HASH);

        assertThat(VnpaySigner.verify(params, SECRET)).isTrue();
    }

    @Test
    void verifyRejectsWhenTheSecureHashIsMissing() {
        Map<String, String> params = baseParams();

        assertThat(VnpaySigner.verify(params, SECRET)).isFalse();
    }

    @Test
    void verifyRejectsWhenOneCharacterInAValueIsAltered() {
        Map<String, String> params = baseParams();
        params.put("vnp_SecureHash", EXPECTED_HASH);
        // Alter a single character of an already-signed value.
        params.put("vnp_TxnRef", "FV000124");

        assertThat(VnpaySigner.verify(params, SECRET)).isFalse();
    }

    @Test
    void verifyRejectsWhenAParameterIsAdded() {
        Map<String, String> params = baseParams();
        params.put("vnp_SecureHash", EXPECTED_HASH);
        params.put("vnp_BankCode", "NCB");

        assertThat(VnpaySigner.verify(params, SECRET)).isFalse();
    }

    @Test
    void verifyRejectsWhenAParameterIsRemoved() {
        Map<String, String> params = baseParams();
        params.put("vnp_SecureHash", EXPECTED_HASH);
        params.remove("vnp_OrderType");

        assertThat(VnpaySigner.verify(params, SECRET)).isFalse();
    }

    @Test
    void signIgnoresParameterOrderingAndEmptyValues() {
        Map<String, String> withEmptyValue = baseParams();
        withEmptyValue.put("vnp_BankCode", "");

        assertThat(VnpaySigner.sign(withEmptyValue, SECRET))
                .isEqualToIgnoringCase(EXPECTED_HASH);
    }
}
