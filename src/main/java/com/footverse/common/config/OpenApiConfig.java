package com.footverse.common.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI (Swagger) configuration.
 *
 * <p>Registers a single HTTP bearer (JWT) security scheme named {@code bearerAuth}, which
 * powers the Swagger UI "Authorize" button. Protected endpoints opt in per-operation via
 * {@code @SecurityRequirement(name = "bearerAuth")} on their controllers, so only those
 * operations display the padlock; public endpoints stay unlocked.</p>
 */
@Configuration
public class OpenApiConfig {

    private static final String SECURITY_SCHEME_NAME = "bearerAuth";

    /**
     * Builds the OpenAPI document with API metadata and the JWT bearer security scheme.
     *
     * @return the configured {@link OpenAPI} bean
     */
    @Bean
    public OpenAPI footVerseOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("FootVerse API")
                        .version("v1")
                        .description("FootVerse e-commerce backend REST API"))
                .components(new Components()
                        .addSecuritySchemes(SECURITY_SCHEME_NAME, new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")));
    }
}
