package com.footverse.auth.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDateTime;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import org.springframework.http.HttpStatus;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.footverse.auth.dto.AuthResponse;
import com.footverse.auth.dto.LoginRequest;
import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.service.AuthService;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.user.dto.UserResponse;
import com.footverse.user.entity.Role;

/**
 * Integration tests for {@link AuthController} register endpoint through the full web stack.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AuthControllerTest {

    private final MockMvc mockMvc;
    private final ObjectMapper objectMapper;

    @MockitoBean
    private AuthService authService;

    AuthControllerTest(@Autowired MockMvc mockMvc, @Autowired ObjectMapper objectMapper) {
        this.mockMvc = mockMvc;
        this.objectMapper = objectMapper;
    }

    private RegisterRequest validRequest() {
        return new RegisterRequest("user@example.com", "Password1", "Test User", "0912345678");
    }

    private LoginRequest validLoginRequest() {
        return new LoginRequest("user@example.com", "Password1");
    }

    /**
     * A valid registration returns 201 with the enveloped {@link AuthResponse} and no password.
     */
    @Test
    void registerReturns201WithAuthResponseEnvelope() throws Exception {
        UserResponse userResponse = new UserResponse(1L, "user@example.com", "Test User", "0912345678",
                null, Role.CUSTOMER, true, LocalDateTime.now(), LocalDateTime.now());
        when(authService.register(any()))
                .thenReturn(new AuthResponse("access-token", "raw-refresh", 900L, "Bearer", userResponse));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validRequest())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.accessToken").value("access-token"))
                .andExpect(jsonPath("$.data.refreshToken").value("raw-refresh"))
                .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.data.expiresIn").value(900))
                .andExpect(jsonPath("$.data.user.email").value("user@example.com"))
                .andExpect(jsonPath("$.data.user.password").doesNotExist());
    }

    /**
     * An invalid body is rejected with 400 VALIDATION_ERROR before reaching the service.
     */
    @Test
    void invalidRequestReturns400() throws Exception {
        RegisterRequest invalid = new RegisterRequest("not-an-email", "short", "", "abc");

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalid)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(authService, never()).register(any());
    }

    /**
     * A duplicate is surfaced as the enveloped 409 from the service exception.
     */
    @Test
    void duplicateReturns409() throws Exception {
        when(authService.register(any()))
                .thenThrow(new DuplicateResourceException("USER_EMAIL_DUPLICATED", "Email already exists"));

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validRequest())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("USER_EMAIL_DUPLICATED"));
    }

    /**
     * A valid login returns 200 with the enveloped {@link AuthResponse} and no password.
     */
    @Test
    void loginReturns200WithAuthResponseEnvelope() throws Exception {
        UserResponse userResponse = new UserResponse(1L, "user@example.com", "Test User", "0912345678",
                null, Role.CUSTOMER, true, LocalDateTime.now(), LocalDateTime.now());
        when(authService.login(any()))
                .thenReturn(new AuthResponse("access-token", "raw-refresh", 900L, "Bearer", userResponse));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validLoginRequest())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.accessToken").value("access-token"))
                .andExpect(jsonPath("$.data.refreshToken").value("raw-refresh"))
                .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.data.expiresIn").value(900))
                .andExpect(jsonPath("$.data.user.email").value("user@example.com"))
                .andExpect(jsonPath("$.data.user.password").doesNotExist());
    }

    /**
     * An invalid login body is rejected with 400 VALIDATION_ERROR before reaching the service.
     */
    @Test
    void invalidLoginRequestReturns400() throws Exception {
        LoginRequest invalid = new LoginRequest("not-an-email", "");

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalid)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(authService, never()).login(any());
    }

    /**
     * Bad credentials surface as the enveloped 401 from the service exception.
     */
    @Test
    void badCredentialsReturns401() throws Exception {
        when(authService.login(any()))
                .thenThrow(new BusinessException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS",
                        "Invalid email or password"));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validLoginRequest())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errorCode").value("INVALID_CREDENTIALS"));
    }

    /**
     * A disabled account surfaces as the enveloped 401 {@code ACCOUNT_DISABLED} from the service.
     */
    @Test
    void disabledAccountReturns401() throws Exception {
        when(authService.login(any()))
                .thenThrow(new BusinessException(HttpStatus.UNAUTHORIZED, "ACCOUNT_DISABLED",
                        "Account is disabled"));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validLoginRequest())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("ACCOUNT_DISABLED"));
    }
}
