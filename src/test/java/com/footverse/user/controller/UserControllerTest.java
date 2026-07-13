package com.footverse.user.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.footverse.common.config.SecurityConfig;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;
import com.footverse.user.service.UserService;

/**
 * Web-slice tests for {@link UserController}. The security filter chain is imported so
 * authentication behaviour is exercised while the service layer is mocked.
 */
@WebMvcTest(UserController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class UserControllerTest {

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private UserService userService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    UserControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
    }

    private String bearerToken() {
        return "Bearer " + jwtUtil.createAccessToken(AuthFixtures.EMAIL);
    }

    /**
     * Returns a bearer token for an authenticated CUSTOMER, stubbing the user-details lookup the JWT
     * filter performs so the request reaches the controller.
     */
    private String authedToken() {
        when(userDetailsService.loadUserByUsername(AuthFixtures.EMAIL))
                .thenReturn(AuthFixtures.userDetails(AuthFixtures.EMAIL, Role.CUSTOMER));
        return bearerToken();
    }

    /**
     * An authenticated call returns 200 with the caller's enveloped profile and no password.
     */
    @Test
    void currentUserAuthenticatedReturns200() throws Exception {
        when(userDetailsService.loadUserByUsername(AuthFixtures.EMAIL))
                .thenReturn(AuthFixtures.userDetails(AuthFixtures.EMAIL, Role.CUSTOMER));
        when(userService.getCurrentUser()).thenReturn(AuthFixtures.userResponse(1L, AuthFixtures.EMAIL));

        mockMvc.perform(get("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, bearerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(1))
                .andExpect(jsonPath("$.data.email").value(AuthFixtures.EMAIL))
                .andExpect(jsonPath("$.data.role").value("CUSTOMER"))
                .andExpect(jsonPath("$.data.password").doesNotExist());

        verify(userService).getCurrentUser();
    }

    /**
     * An anonymous call (no access token) is rejected by the security chain with the enveloped
     * 401, never reaching the service.
     */
    @Test
    void currentUserAnonymousReturns401() throws Exception {
        mockMvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(userService, never()).getCurrentUser();
    }

    // ----- PUT /users/me (profile update) -----

    /**
     * {@code PUT /users/me} returns {@code 200} with the caller's refreshed profile.
     */
    @Test
    void updateProfileReturns200() throws Exception {
        when(userService.updateProfile(any())).thenReturn(AuthFixtures.userResponse(1L, AuthFixtures.EMAIL));

        mockMvc.perform(put("/api/v1/users/me")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"New Name\",\"phone\":\"0912345678\",\"avatarUrl\":\"http://a\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(1));
    }

    /**
     * A blank {@code fullName} fails Bean Validation with the enveloped {@code 400}; the service is
     * never reached.
     */
    @Test
    void updateProfileWithBlankFullNameReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/users/me")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"\",\"phone\":\"0912345678\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[0].field").value("fullName"));

        verify(userService, never()).updateProfile(any());
    }

    /**
     * A phone held by another account surfaces the service's {@code 409 USER_PHONE_DUPLICATED}.
     */
    @Test
    void updateProfileWithDuplicatePhoneReturns409() throws Exception {
        when(userService.updateProfile(any()))
                .thenThrow(new DuplicateResourceException("USER_PHONE_DUPLICATED", "Phone already exists"));

        mockMvc.perform(put("/api/v1/users/me")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"New Name\",\"phone\":\"0912345678\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("USER_PHONE_DUPLICATED"));
    }

    /**
     * An anonymous {@code PUT /users/me} is denied the enveloped {@code 401}; the service is never
     * reached.
     */
    @Test
    void updateProfileAnonymouslyReturns401() throws Exception {
        mockMvc.perform(put("/api/v1/users/me")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"New Name\",\"phone\":\"0912345678\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(userService, never()).updateProfile(any());
    }

    // ----- PATCH /users/me/password (change password) -----

    /**
     * {@code PATCH /users/me/password} returns {@code 200} with an empty payload on success.
     */
    @Test
    void changePasswordReturns200() throws Exception {
        mockMvc.perform(patch("/api/v1/users/me/password")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"Password1\",\"newPassword\":\"NewPassword1\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        verify(userService).changePassword(any());
    }

    /**
     * A new password that violates the shape rule fails Bean Validation with the enveloped
     * {@code 400}; the service is never reached.
     */
    @Test
    void changePasswordWithWeakNewPasswordReturns400() throws Exception {
        mockMvc.perform(patch("/api/v1/users/me/password")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"Password1\",\"newPassword\":\"short\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[0].field").value("newPassword"));

        verify(userService, never()).changePassword(any());
    }

    /**
     * A wrong current password surfaces the service's {@code 400 USER_CURRENT_PASSWORD_INVALID}
     * (never a {@code 401} — the call is already authenticated).
     */
    @Test
    void changePasswordWithWrongCurrentPasswordReturns400() throws Exception {
        doThrow(new BusinessException(HttpStatus.BAD_REQUEST, "USER_CURRENT_PASSWORD_INVALID",
                        "Current password is incorrect"))
                .when(userService).changePassword(any());

        mockMvc.perform(patch("/api/v1/users/me/password")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"wrong-password\",\"newPassword\":\"NewPassword1\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("USER_CURRENT_PASSWORD_INVALID"));
    }

    /**
     * An anonymous {@code PATCH /users/me/password} is denied the enveloped {@code 401}.
     */
    @Test
    void changePasswordAnonymouslyReturns401() throws Exception {
        mockMvc.perform(patch("/api/v1/users/me/password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"Password1\",\"newPassword\":\"NewPassword1\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(userService, never()).changePassword(any());
    }

    // ----- PATCH /users/me/email (change email) -----

    /**
     * {@code PATCH /users/me/email} returns {@code 200} with the caller's refreshed profile carrying
     * the new email.
     */
    @Test
    void changeEmailReturns200() throws Exception {
        when(userService.changeEmail(any())).thenReturn(AuthFixtures.userResponse(1L, "new@example.com"));

        mockMvc.perform(patch("/api/v1/users/me/email")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"newEmail\":\"new@example.com\",\"currentPassword\":\"Password1\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.email").value("new@example.com"));
    }

    /**
     * A malformed email fails Bean Validation with the enveloped {@code 400}; the service is never
     * reached.
     */
    @Test
    void changeEmailWithInvalidEmailReturns400() throws Exception {
        mockMvc.perform(patch("/api/v1/users/me/email")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"newEmail\":\"not-an-email\",\"currentPassword\":\"Password1\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[0].field").value("newEmail"));

        verify(userService, never()).changeEmail(any());
    }

    /**
     * A wrong current password surfaces the service's {@code 400 USER_CURRENT_PASSWORD_INVALID}.
     */
    @Test
    void changeEmailWithWrongCurrentPasswordReturns400() throws Exception {
        when(userService.changeEmail(any()))
                .thenThrow(new BusinessException(HttpStatus.BAD_REQUEST, "USER_CURRENT_PASSWORD_INVALID",
                        "Current password is incorrect"));

        mockMvc.perform(patch("/api/v1/users/me/email")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"newEmail\":\"new@example.com\",\"currentPassword\":\"wrong-password\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("USER_CURRENT_PASSWORD_INVALID"));
    }

    /**
     * An email held by another account surfaces the service's {@code 409 USER_EMAIL_DUPLICATED}.
     */
    @Test
    void changeEmailWithDuplicateEmailReturns409() throws Exception {
        when(userService.changeEmail(any()))
                .thenThrow(new DuplicateResourceException("USER_EMAIL_DUPLICATED", "Email already exists"));

        mockMvc.perform(patch("/api/v1/users/me/email")
                        .header(HttpHeaders.AUTHORIZATION, authedToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"newEmail\":\"taken@example.com\",\"currentPassword\":\"Password1\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("USER_EMAIL_DUPLICATED"));
    }

    /**
     * An anonymous {@code PATCH /users/me/email} is denied the enveloped {@code 401}.
     */
    @Test
    void changeEmailAnonymouslyReturns401() throws Exception {
        mockMvc.perform(patch("/api/v1/users/me/email")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"newEmail\":\"new@example.com\",\"currentPassword\":\"Password1\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(userService, never()).changeEmail(any());
    }
}
