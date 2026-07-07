package com.footverse.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.access.AccessDeniedException;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Verifies that {@link RestAccessDeniedHandler} writes the enveloped 403 response directly,
 * since the skeleton has no authenticated users/roles to trigger a 403 through the filter
 * chain yet.
 */
class RestAccessDeniedHandlerTest {

    /**
     * Handling an {@link AccessDeniedException} yields a 403 JSON envelope with error code
     * {@code FORBIDDEN} and no leaked internal detail.
     *
     * @throws Exception if the response cannot be written or parsed
     */
    @Test
    void writesForbiddenEnvelope() throws Exception {
        ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();
        RestAccessDeniedHandler handler = new RestAccessDeniedHandler(objectMapper);
        MockHttpServletResponse response = new MockHttpServletResponse();

        handler.handle(new MockHttpServletRequest("GET", "/api/v1/cart"), response,
                new AccessDeniedException("denied"));

        assertThat(response.getStatus()).isEqualTo(403);
        assertThat(response.getContentType()).contains("application/json");

        JsonNode body = objectMapper.readTree(response.getContentAsString());
        assertThat(body.get("success").asBoolean()).isFalse();
        assertThat(body.get("errorCode").asText()).isEqualTo("FORBIDDEN");
        assertThat(body.get("message").asText()).isEqualTo("You cannot access this resource");
    }
}
