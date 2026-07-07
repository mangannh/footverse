package com.footverse.common.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Verifies that the OpenAPI document exposes the JWT bearer security scheme and that the
 * Swagger UI page is served.
 *
 * <p>Security filters are disabled ({@code addFilters = false}) because no {@code
 * SecurityConfig} exists yet (owned by a later task); the default security chain would
 * otherwise return 401 for every path, including the Swagger endpoints.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
class OpenApiDocumentationTest {

    private final MockMvc mockMvc;

    OpenApiDocumentationTest(@Autowired MockMvc mockMvc) {
        this.mockMvc = mockMvc;
    }

    /**
     * The generated OpenAPI document declares the {@code bearerAuth} HTTP/JWT scheme.
     */
    @Test
    void apiDocsExposeBearerAuthScheme() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.components.securitySchemes.bearerAuth.type").value("http"))
                .andExpect(jsonPath("$.components.securitySchemes.bearerAuth.scheme").value("bearer"))
                .andExpect(jsonPath("$.components.securitySchemes.bearerAuth.bearerFormat").value("JWT"));
    }

    /**
     * The Swagger UI page is served (confirming static UI resources are reachable).
     */
    @Test
    void swaggerUiPageIsServed() throws Exception {
        mockMvc.perform(get("/swagger-ui/index.html"))
                .andExpect(status().isOk());
    }
}
