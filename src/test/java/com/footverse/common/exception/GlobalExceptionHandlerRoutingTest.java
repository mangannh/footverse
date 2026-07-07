package com.footverse.common.exception;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Verifies that a request to an unmapped endpoint is routed into
 * {@link GlobalExceptionHandler} as a {@code NoHandlerFoundException} and rendered as the
 * standard {@code 404 RESOURCE_NOT_FOUND} envelope.
 *
 * <p>Security filters are disabled ({@code addFilters = false}) so the request reaches the
 * DispatcherServlet. The security layer (its own 401/403 behaviour) is owned by a later task
 * and is intentionally out of scope here.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
class GlobalExceptionHandlerRoutingTest {

    private final MockMvc mockMvc;

    GlobalExceptionHandlerRoutingTest(@Autowired MockMvc mockMvc) {
        this.mockMvc = mockMvc;
    }

    /**
     * A request to a non-existent path returns the {@code 404 RESOURCE_NOT_FOUND} envelope.
     */
    @Test
    void unknownEndpointReturnsResourceNotFoundEnvelope() throws Exception {
        mockMvc.perform(get("/this-does-not-exist"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("RESOURCE_NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("Resource not found"));
    }
}
