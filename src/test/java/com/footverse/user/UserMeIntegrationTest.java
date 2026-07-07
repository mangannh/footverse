package com.footverse.user;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import com.footverse.auth.dto.RegisterRequest;
import com.footverse.auth.service.AuthService;
import com.footverse.common.security.JwtUtil;

/**
 * End-to-end test proving {@code GET /users/me} always returns the caller resolved from the
 * access token — never another user and never a request parameter. Two users are registered and
 * each token yields exactly its own profile.
 *
 * <p>Runs in a rolled-back transaction so the registered users leave no persisted state.</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class UserMeIntegrationTest {

    private final MockMvc mockMvc;
    private final AuthService authService;
    private final JwtUtil jwtUtil;

    UserMeIntegrationTest(@Autowired MockMvc mockMvc, @Autowired AuthService authService,
                          @Autowired JwtUtil jwtUtil) {
        this.mockMvc = mockMvc;
        this.authService = authService;
        this.jwtUtil = jwtUtil;
    }

    private void register(String email, String phone, String fullName) {
        authService.register(new RegisterRequest(email, "Password1", fullName, phone));
    }

    /**
     * Each caller's token returns that caller's own profile: Alice's token yields Alice, Bob's
     * token yields Bob — proving the endpoint is driven solely by the authenticated identity.
     */
    @Test
    void currentUserAlwaysReturnsTheCaller() throws Exception {
        register("alice@example.com", "0900000018", "Alice");
        register("bob@example.com", "0900000019", "Bob");

        mockMvc.perform(get("/api/v1/users/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwtUtil.createAccessToken("alice@example.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email").value("alice@example.com"))
                .andExpect(jsonPath("$.data.fullName").value("Alice"));

        mockMvc.perform(get("/api/v1/users/me")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + jwtUtil.createAccessToken("bob@example.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email").value("bob@example.com"))
                .andExpect(jsonPath("$.data.fullName").value("Bob"));
    }
}
