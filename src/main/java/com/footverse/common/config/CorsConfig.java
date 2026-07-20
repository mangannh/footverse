package com.footverse.common.config;

import java.util.Arrays;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * CORS configuration for browser clients (Chrome/Flutter Web, the React admin panel).
 *
 * <p>This has no effect on the native Android/iOS app: a CORS preflight ({@code OPTIONS}
 * with {@code Access-Control-Request-Method}) is issued only by a browser's own
 * fetch/XHR implementation, never by a native HTTP client such as Dio's {@code dart:io}
 * adapter. The allowed origins come from {@code footverse.cors.allowed-origin-patterns}
 * (no origin is hardcoded here) so each environment supplies its own list — no default in
 * {@code application.yml}, and {@code application-local.yml} supplies the permissive
 * local-dev value, exactly like {@code footverse.jwt.secret}.</p>
 */
@Configuration
public class CorsConfig {

    /**
     * Builds the {@link CorsConfigurationSource} Spring Security's {@code cors()} DSL
     * auto-discovers, from the configured comma-separated origin patterns.
     *
     * @param allowedOriginPatterns comma-separated origin patterns
     *                              (e.g. {@code http://localhost:*,http://127.0.0.1:*});
     *                              blank entries are ignored
     * @return the {@link CorsConfigurationSource} registered for every path
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource(
            @Value("${footverse.cors.allowed-origin-patterns}") String allowedOriginPatterns) {
        CorsConfiguration configuration = new CorsConfiguration();

        configuration.setAllowedOriginPatterns(
                Arrays.stream(allowedOriginPatterns.split(","))
                        .map(String::trim)
                        .filter(pattern -> !pattern.isEmpty())
                        .toList());

        configuration.setAllowedMethods(List.of(
                "GET",
                "POST",
                "PUT",
                "PATCH",
                "DELETE",
                "OPTIONS"
        ));

        configuration.setAllowedHeaders(List.of("*"));

        configuration.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source =
                new UrlBasedCorsConfigurationSource();

        source.registerCorsConfiguration("/**", configuration);

        return source;
    }
}
