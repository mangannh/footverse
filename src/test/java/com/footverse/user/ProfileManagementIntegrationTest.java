package com.footverse.user;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.service.AuthService;
import com.footverse.common.security.JwtUtil;

/**
 * End-to-end profile-management flow through the real filter chain, services, and database (no mocks,
 * sprint-5-plan item 10). A registered CUSTOMER updates their profile, changes their password, and
 * changes their email, and the test proves each consequence against live credentials:
 *
 * <ul>
 *   <li>after a password change the old password no longer logs in and the new one does;</li>
 *   <li>a wrong current password is the enveloped {@code 400 USER_CURRENT_PASSWORD_INVALID} with
 *       <strong>no</strong> state change (the credential still works, the rejected one does not);</li>
 *   <li>the new email is normalized lowercase; after the change the old access token no longer
 *       resolves ({@code 401}), the old email no longer logs in, and the new email does (assumption 7 —
 *       nothing is revoked, the old token simply dies because its subject is the former email).</li>
 * </ul>
 *
 * <p>Real BCrypt encoding and verification run throughout (no mock), so the encode / matches paths are
 * exercised end-to-end. Runs in a rolled-back transaction so no state leaks.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class ProfileManagementIntegrationTest {

    private static final String ORIGINAL_EMAIL = "profile-user@example.com";
    private static final String NEW_EMAIL = "new-profile@example.com";
    private static final String PHONE = "0900000081";
    private static final String ORIGINAL_PASSWORD = "Password1";
    private static final String NEW_PASSWORD = "NewPassword1";

    private final MockMvc mockMvc;
    private final AuthService authService;
    private final JwtUtil jwtUtil;

    ProfileManagementIntegrationTest(@Autowired MockMvc mockMvc, @Autowired AuthService authService,
            @Autowired JwtUtil jwtUtil) {
        this.mockMvc = mockMvc;
        this.authService = authService;
        this.jwtUtil = jwtUtil;
    }

    @BeforeEach
    void registerUser() {
        authService.register(new RegisterRequest(ORIGINAL_EMAIL, ORIGINAL_PASSWORD, "Original Name", PHONE));
    }

    /** Bearer token for the original email (the JWT subject before any email change). */
    private String originalEmailToken() {
        return "Bearer " + jwtUtil.createAccessToken(ORIGINAL_EMAIL);
    }

    /** Attempts a login and asserts the expected HTTP status; returns the result for further checks. */
    private void login(String email, String password, int expectedStatus) throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}"))
                .andExpect(status().is(expectedStatus));
    }

    /**
     * Walks the whole profile-management flow: profile update, password change (with the login
     * consequences and the wrong-password no-op rejection), and email change (with the token/login
     * consequences and lowercase normalization).
     */
    @Test
    void customerUpdatesProfileThenChangesPasswordAndEmail() throws Exception {
        String token = originalEmailToken();

        // 1. Profile update: the editable fields change and are returned.
        mockMvc.perform(put("/api/v1/users/me")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"Updated Name\",\"phone\":\"0900000082\","
                                + "\"avatarUrl\":\"http://avatar/new.png\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.fullName").value("Updated Name"))
                .andExpect(jsonPath("$.data.phone").value("0900000082"))
                .andExpect(jsonPath("$.data.avatarUrl").value("http://avatar/new.png"))
                .andExpect(jsonPath("$.data.email").value(ORIGINAL_EMAIL));

        // 2. Change password with the correct current password.
        mockMvc.perform(patch("/api/v1/users/me/password")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"" + ORIGINAL_PASSWORD + "\","
                                + "\"newPassword\":\"" + NEW_PASSWORD + "\"}"))
                .andExpect(status().isOk());

        // 3. The old password no longer logs in; the new password does.
        login(ORIGINAL_EMAIL, ORIGINAL_PASSWORD, 401);
        login(ORIGINAL_EMAIL, NEW_PASSWORD, 200);

        // 4. A wrong current password is 400 USER_CURRENT_PASSWORD_INVALID and changes nothing.
        mockMvc.perform(patch("/api/v1/users/me/password")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"currentPassword\":\"totally-wrong\",\"newPassword\":\"Rejected1\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("USER_CURRENT_PASSWORD_INVALID"));
        login(ORIGINAL_EMAIL, "Rejected1", 401);   // the rejected password never took effect
        login(ORIGINAL_EMAIL, NEW_PASSWORD, 200);   // the real password still works

        // 5. Change email; the new email is normalized lowercase.
        mockMvc.perform(patch("/api/v1/users/me/email")
                        .header(HttpHeaders.AUTHORIZATION, token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"newEmail\":\"New-Profile@Example.com\","
                                + "\"currentPassword\":\"" + NEW_PASSWORD + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email").value(NEW_EMAIL));

        // 6. The old access token (subject = old email) no longer resolves after the email change.
        mockMvc.perform(get("/api/v1/users/me").header(HttpHeaders.AUTHORIZATION, token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        // 7. The old email no longer logs in; the new email does (with the current password).
        login(ORIGINAL_EMAIL, NEW_PASSWORD, 401);
        login(NEW_EMAIL, NEW_PASSWORD, 200);
    }
}
