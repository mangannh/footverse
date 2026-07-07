package com.footverse.common.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Verifies the security skeleton end-to-end through the real filter chain: public endpoints
 * pass, protected endpoints return the enveloped 401, and {@code POST /auth/logout} is not
 * public.
 */
@SpringBootTest
@AutoConfigureMockMvc
class SecurityConfigTest {

    private final MockMvc mockMvc;

    SecurityConfigTest(@Autowired MockMvc mockMvc) {
        this.mockMvc = mockMvc;
    }

    /**
     * The OpenAPI docs endpoint is public and reachable once security is enabled.
     */
    @Test
    void swaggerApiDocsArePublic() throws Exception {
        mockMvc.perform(get("/v3/api-docs")).andExpect(status().isOk());
    }

    /**
     * A protected endpoint with no authentication returns the enveloped 401.
     */
    @Test
    void protectedEndpointReturnsEnveloped401() throws Exception {
        mockMvc.perform(get("/api/v1/cart"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.message").value("Authentication required"));
    }

    /**
     * {@code POST /auth/logout} is authenticated-only (not public), so it returns 401.
     */
    @Test
    void logoutIsNotPublic() throws Exception {
        mockMvc.perform(post("/api/v1/auth/logout"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));
    }

    /**
     * A public auth endpoint passes security: an unauthenticated {@code POST /auth/login} is not
     * blocked with 401 but reaches the controller, where the empty body fails request parsing and
     * resolves to the enveloped 400 {@code VALIDATION_ERROR} (proving security let it through).
     */
    @Test
    void publicAuthEndpointPassesSecurity() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));
    }

    /**
     * A public product GET passes security (resolves to routing-404, not 401).
     */
    @Test
    void publicProductGetPassesSecurity() throws Exception {
        mockMvc.perform(get("/api/v1/products/1"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("RESOURCE_NOT_FOUND"));
    }
}
