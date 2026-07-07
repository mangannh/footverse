package com.footverse.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Unit tests for {@link JwtFilter} SecurityContext population and rejection behaviour.
 */
class JwtFilterTest {

    private static final String SECRET = "test-secret-key-that-is-at-least-32-bytes-long";
    private static final String SUBJECT = "user@example.com";

    private final ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();
    private final JwtUtil jwtUtil = new JwtUtil(SECRET, 900);
    private final JwtFilter jwtFilter =
            new JwtFilter(jwtUtil, new RestAuthenticationEntryPoint(objectMapper));

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    /**
     * A valid Bearer token populates the SecurityContext with the subject and lets the request
     * proceed.
     *
     * @throws Exception if filtering fails
     */
    @Test
    void validTokenPopulatesSecurityContext() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/cart");
        request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer " + jwtUtil.createAccessToken(SUBJECT));
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        jwtFilter.doFilter(request, response, chain);

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        assertThat(authentication).isNotNull();
        assertThat(authentication.isAuthenticated()).isTrue();
        assertThat(authentication.getPrincipal()).isEqualTo(SUBJECT);
        assertThat(chain.getRequest()).as("request should proceed down the chain").isNotNull();
    }

    /**
     * An invalid Bearer token is rejected with the enveloped 401 and does not proceed.
     *
     * @throws Exception if filtering fails
     */
    @Test
    void invalidTokenIsRejectedWithEnveloped401() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/cart");
        request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer invalid-token");
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        jwtFilter.doFilter(request, response, chain);

        assertThat(response.getStatus()).isEqualTo(401);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
        assertThat(chain.getRequest()).as("request should not proceed").isNull();

        JsonNode body = objectMapper.readTree(response.getContentAsString());
        assertThat(body.get("success").asBoolean()).isFalse();
        assertThat(body.get("errorCode").asText()).isEqualTo("UNAUTHORIZED");
    }
}
