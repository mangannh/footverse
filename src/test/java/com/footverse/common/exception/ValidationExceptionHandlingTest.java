package com.footverse.common.exception;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.footverse.common.dto.ApiResponse;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

/**
 * Verifies that Bean Validation failures and malformed request bodies are rendered as the
 * standard {@code 400 VALIDATION_ERROR} envelope by {@link GlobalExceptionHandler}.
 *
 * <p>Uses a standalone MockMvc with a test-only controller and request DTO (test scope only,
 * never in the main source) wired to the real handler, isolating the validation pipeline from
 * the full application context.</p>
 */
class ValidationExceptionHandlingTest {

    private final MockMvc mockMvc = MockMvcBuilders
            .standaloneSetup(new TestController())
            .setControllerAdvice(new GlobalExceptionHandler())
            .build();

    /**
     * A request that violates field constraints returns {@code VALIDATION_ERROR} with a
     * populated {@code errors} array.
     */
    @Test
    void invalidFieldsReturnValidationErrorEnvelope() throws Exception {
        mockMvc.perform(post("/test/echo")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"quantity\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.message").value("Validation failed"))
                .andExpect(jsonPath("$.errors").isArray())
                .andExpect(jsonPath("$.errors[0].field").exists())
                .andExpect(jsonPath("$.errors[0].message").exists());
    }

    /**
     * A malformed JSON body returns {@code VALIDATION_ERROR} with no field-level errors.
     */
    @Test
    void malformedJsonReturnsMalformedBodyEnvelope() throws Exception {
        mockMvc.perform(post("/test/echo")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{ not valid json"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.message").value("Malformed request body"));
    }

    /**
     * Test-only controller exposing a single endpoint that validates its request body.
     */
    @RestController
    static class TestController {

        /**
         * Echoes a validated request; only the validation failure path is exercised by tests.
         *
         * @param request the validated request body
         * @return an empty success envelope
         */
        @PostMapping("/test/echo")
        ApiResponse<Void> echo(@Valid @RequestBody TestRequest request) {
            return ApiResponse.ok(null);
        }
    }

    /**
     * Test-only request DTO carrying field constraints to trigger Bean Validation.
     *
     * @param name     a non-blank name
     * @param quantity a quantity of at least one
     */
    record TestRequest(@NotBlank String name, @Min(1) int quantity) {
    }
}
