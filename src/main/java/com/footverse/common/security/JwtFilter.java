package com.footverse.common.security;

import java.io.IOException;
import java.util.Collections;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Per-request filter that authenticates a Bearer access token.
 *
 * <p>When a valid token is present, the subject is placed in the {@link SecurityContextHolder}
 * as an authenticated principal (authorities are populated by a later task). When a token is
 * present but invalid, the request is rejected through the {@link RestAuthenticationEntryPoint}
 * with the enveloped 401. Requests without a Bearer token are passed through untouched, so the
 * authorization layer decides (public served, protected → enveloped 401). The filter performs
 * authentication only — no business logic.</p>
 */
@Slf4j
@RequiredArgsConstructor
public class JwtFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtUtil jwtUtil;
    private final RestAuthenticationEntryPoint authenticationEntryPoint;

    /**
     * Authenticates the request from its Bearer token, if any.
     *
     * @param request     the current request
     * @param response    the current response
     * @param filterChain the remaining filter chain
     * @throws ServletException if the downstream chain fails
     * @throws IOException      if writing the rejection response fails
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String token = extractBearerToken(request);
        if (token != null) {
            if (jwtUtil.isValid(token)) {
                if (SecurityContextHolder.getContext().getAuthentication() == null) {
                    setAuthentication(jwtUtil.getSubject(token));
                }
            } else {
                SecurityContextHolder.clearContext();
                log.warn("Rejected invalid JWT for {} {}", request.getMethod(), request.getRequestURI());
                authenticationEntryPoint.commence(request, response, new BadCredentialsException("Invalid JWT"));
                return;
            }
        }
        filterChain.doFilter(request, response);
    }

    private String extractBearerToken(HttpServletRequest request) {
        String header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (header != null && header.startsWith(BEARER_PREFIX)) {
            return header.substring(BEARER_PREFIX.length());
        }
        return null;
    }

    private void setAuthentication(String subject) {
        UsernamePasswordAuthenticationToken authentication =
                new UsernamePasswordAuthenticationToken(subject, null, Collections.emptyList());
        SecurityContextHolder.getContext().setAuthentication(authentication);
    }
}
