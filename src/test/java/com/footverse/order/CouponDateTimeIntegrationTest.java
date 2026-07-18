package com.footverse.order;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.common.security.JwtUtil;
import com.footverse.support.AuthFixtures;
import com.footverse.user.repository.UserRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;

/**
 * Proves the coupon {@code start_at} / {@code end_at} {@code DATETIME} round-trip carries the
 * exact wall-clock value the client sent, with no implicit timezone reinterpretation between the
 * JDBC driver's temporal binding and the actually-persisted bytes (the "Coupon DateTime Timezone
 * Bug" fixed by {@code preserveInstants=false} on the local datasource URL).
 *
 * <p>Reading the value back through the application's own JPA/{@code LocalDateTime} path cannot
 * detect a driver-side timezone conversion, because MySQL Connector/J applies the same conversion
 * (and its exact inverse) symmetrically on write and on read — the shift is only visible to a
 * consumer that reads the raw column bytes without that client-side reinterpretation (e.g. the
 * {@code mysql} CLI, or any tool reading the value as a server-formatted string). This test forces
 * MySQL itself to format the column with {@code DATE_FORMAT} — a plain string leaves the server,
 * so the JDBC driver never touches a {@code Timestamp}/{@code LocalDateTime} binding on the way
 * back, and no client-side conversion (of any driver configuration) can mask a write-time shift.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class CouponDateTimeIntegrationTest {

    private static final String ADMIN_EMAIL = "tz-admin@example.com";
    private static final String ADMIN_PHONE = "0900000098";
    private static final String COUPON_CODE = "TZ-ROUNDTRIP";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;
    private final UserRepository userRepository;
    private final EntityManager entityManager;

    CouponDateTimeIntegrationTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil,
            @Autowired UserRepository userRepository, @Autowired EntityManager entityManager) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
        this.entityManager = entityManager;
    }

    @Test
    void startAtAndEndAtRoundTripWithoutTimezoneShift() throws Exception {
        userRepository.save(AuthFixtures.admin(ADMIN_EMAIL, ADMIN_PHONE));
        String token = "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);

        String body = "{\"code\":\"" + COUPON_CODE + "\",\"name\":\"TZ Roundtrip\","
                + "\"discountType\":\"FIXED\",\"discountValue\":10,\"minOrderAmount\":0,"
                + "\"startAt\":\"2026-07-18T10:18:00\",\"endAt\":\"2026-07-18T10:30:00\",\"enabled\":true}";

        // The API response already reflects the sent wall-clock value — this alone does not
        // prove the database row is correct, since the app's own read path would silently
        // reverse whatever its own write path shifted.
        mockMvc.perform(post("/api/v1/coupons")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.startAt").value("2026-07-18T10:18:00"))
                .andExpect(jsonPath("$.data.endAt").value("2026-07-18T10:30:00"));

        entityManager.flush();

        // Server-side DATE_FORMAT: MySQL returns a plain string, so the JDBC driver never binds
        // this value as a Timestamp/LocalDateTime on the way back — the raw stored bytes, exactly
        // as an external SQL client would see them.
        Query query = entityManager.createNativeQuery(
                "SELECT DATE_FORMAT(start_at, '%Y-%m-%dT%H:%i:%s'), "
                        + "DATE_FORMAT(end_at, '%Y-%m-%dT%H:%i:%s') "
                        + "FROM coupon WHERE code = :code");
        query.setParameter("code", COUPON_CODE);
        Object[] row = (Object[]) query.getSingleResult();

        assertThat(row[0]).isEqualTo("2026-07-18T10:18:00");
        assertThat(row[1]).isEqualTo("2026-07-18T10:30:00");
    }
}
