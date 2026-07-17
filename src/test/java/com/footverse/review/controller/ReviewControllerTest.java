package com.footverse.review.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import com.footverse.common.config.SecurityConfig;
import com.footverse.common.dto.PageResponse;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.ResourceNotFoundException;
import com.footverse.common.security.JwtUtil;
import com.footverse.common.security.RestAccessDeniedHandler;
import com.footverse.common.security.RestAuthenticationEntryPoint;
import com.footverse.review.dto.ReviewResponse;
import com.footverse.review.service.ReviewService;
import com.footverse.support.AuthFixtures;
import com.footverse.user.entity.Role;

/**
 * Web-slice tests for {@link ReviewController}: the public product-review listing
 * ({@code GET /products/{id}/reviews}) and the CUSTOMER-only write surface ({@code POST /reviews},
 * {@code PUT /reviews/{id}}, {@code DELETE /reviews/{id}}). They assert the success envelopes,
 * request-body / path validation, the anonymous access split (listing open, writes {@code 401}), the
 * role denial for an ADMIN token on the writes (CUSTOMER-only, both directions), and the
 * eligibility / duplicate / ownership business errors rendered through the standard envelope. The
 * security filter chain is imported; the service is mocked, so no business rule runs here.
 */
@WebMvcTest(ReviewController.class)
@Import({SecurityConfig.class, JwtUtil.class, RestAuthenticationEntryPoint.class, RestAccessDeniedHandler.class})
class ReviewControllerTest {

    private static final String CUSTOMER_EMAIL = "customer@example.com";
    private static final String ADMIN_EMAIL = "admin@example.com";

    private final MockMvc mockMvc;
    private final JwtUtil jwtUtil;

    @MockitoBean
    private ReviewService reviewService;

    @MockitoBean
    private UserDetailsService userDetailsService;

    ReviewControllerTest(@Autowired MockMvc mockMvc, @Autowired JwtUtil jwtUtil) {
        this.mockMvc = mockMvc;
        this.jwtUtil = jwtUtil;
    }

    private String customerToken() {
        when(userDetailsService.loadUserByUsername(CUSTOMER_EMAIL))
                .thenReturn(AuthFixtures.userDetails(CUSTOMER_EMAIL, Role.CUSTOMER));
        return "Bearer " + jwtUtil.createAccessToken(CUSTOMER_EMAIL);
    }

    private String adminToken() {
        when(userDetailsService.loadUserByUsername(ADMIN_EMAIL))
                .thenReturn(AuthFixtures.userDetails(ADMIN_EMAIL, Role.ADMIN));
        return "Bearer " + jwtUtil.createAccessToken(ADMIN_EMAIL);
    }

    private ReviewResponse reviewResponse() {
        return new ReviewResponse(55L, 100L, 7L, "Reviewer", "http://avatar", 4, "Solid",
                LocalDateTime.now(), LocalDateTime.now());
    }

    // ----- GET /products/{id}/reviews (public listing) -----

    /**
     * The listing is public: an anonymous caller gets {@code 200} with the page of reviews.
     */
    @Test
    void listReviewsAnonymouslyReturns200() throws Exception {
        when(reviewService.getProductReviews(eq(100L), any(Pageable.class)))
                .thenReturn(PageResponse.from(new PageImpl<>(List.of(reviewResponse()))));

        mockMvc.perform(get("/api/v1/products/100/reviews"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.content[0].id").value(55))
                .andExpect(jsonPath("$.data.content[0].productId").value(100))
                .andExpect(jsonPath("$.data.content[0].userId").value(7))
                .andExpect(jsonPath("$.data.content[0].userFullName").value("Reviewer"))
                .andExpect(jsonPath("$.data.content[0].rating").value(4));
    }

    /**
     * A non-numeric product id is a type mismatch rendered as the enveloped {@code 400
     * VALIDATION_ERROR}; the service is never reached.
     */
    @Test
    void listReviewsWithNonNumericIdReturns400() throws Exception {
        mockMvc.perform(get("/api/v1/products/abc/reviews"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(reviewService, never()).getProductReviews(any(), any());
    }

    // ----- POST /reviews -----

    /**
     * {@code POST /reviews} as a CUSTOMER returns {@code 201 Created} with the created review.
     */
    @Test
    void createReviewAsCustomerReturns201() throws Exception {
        when(reviewService.createReview(any())).thenReturn(reviewResponse());

        mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":100,\"rating\":4,\"comment\":\"Solid\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(55))
                .andExpect(jsonPath("$.data.productId").value(100))
                .andExpect(jsonPath("$.data.userId").value(7))
                .andExpect(jsonPath("$.data.rating").value(4));
    }

    /**
     * A rating outside {@code 1..5} fails Bean Validation with the enveloped {@code 400}; the service
     * is never reached.
     */
    @Test
    void createReviewWithOutOfRangeRatingReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":100,\"rating\":9}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[0].field").value("rating"));

        verify(reviewService, never()).createReview(any());
    }

    /**
     * An anonymous {@code POST /reviews} is denied the enveloped {@code 401}; the service is never
     * reached.
     */
    @Test
    void createReviewAnonymouslyReturns401() throws Exception {
        mockMvc.perform(post("/api/v1/reviews")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":100,\"rating\":4}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(reviewService, never()).createReview(any());
    }

    /**
     * {@code POST /reviews} with an ADMIN token is denied the enveloped {@code 403}: the review writes
     * are CUSTOMER-only (security-spec §6).
     */
    @Test
    void createReviewAsAdminReturns403() throws Exception {
        mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":100,\"rating\":4}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        verify(reviewService, never()).createReview(any());
    }

    /**
     * An ineligible caller surfaces the service's {@code 403 REVIEW_NOT_ELIGIBLE} through the standard
     * envelope.
     */
    @Test
    void createReviewWhenIneligibleReturns403() throws Exception {
        when(reviewService.createReview(any()))
                .thenThrow(new BusinessException(HttpStatus.FORBIDDEN, "REVIEW_NOT_ELIGIBLE",
                        "You can only review a product you have received in a delivered order"));

        mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":100,\"rating\":4}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_NOT_ELIGIBLE"));
    }

    /**
     * A second review of the same product surfaces the service's {@code 409 REVIEW_DUPLICATED}.
     */
    @Test
    void createReviewWhenDuplicateReturns409() throws Exception {
        when(reviewService.createReview(any()))
                .thenThrow(new DuplicateResourceException("REVIEW_DUPLICATED",
                        "You have already reviewed this product"));

        mockMvc.perform(post("/api/v1/reviews")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":100,\"rating\":4}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_DUPLICATED"));
    }

    // ----- PUT /reviews/{id} -----

    /**
     * {@code PUT /reviews/{id}} as the owning CUSTOMER returns {@code 200 OK} with the updated review.
     */
    @Test
    void updateReviewAsCustomerReturns200() throws Exception {
        when(reviewService.updateReview(eq(55L), any())).thenReturn(reviewResponse());

        mockMvc.perform(put("/api/v1/reviews/55")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":5,\"comment\":\"Even better\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.id").value(55));
    }

    /**
     * A missing rating fails Bean Validation with the enveloped {@code 400}; the service is never
     * reached.
     */
    @Test
    void updateReviewWithInvalidRatingReturns400() throws Exception {
        mockMvc.perform(put("/api/v1/reviews/55")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.errors[0].field").value("rating"));

        verify(reviewService, never()).updateReview(any(), any());
    }

    /**
     * An anonymous {@code PUT /reviews/{id}} is denied the enveloped {@code 401}.
     */
    @Test
    void updateReviewAnonymouslyReturns401() throws Exception {
        mockMvc.perform(put("/api/v1/reviews/55")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":5}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(reviewService, never()).updateReview(any(), any());
    }

    /**
     * {@code PUT /reviews/{id}} with an ADMIN token is denied the enveloped {@code 403}: the review
     * writes are CUSTOMER-only.
     */
    @Test
    void updateReviewAsAdminReturns403() throws Exception {
        mockMvc.perform(put("/api/v1/reviews/55")
                        .header(HttpHeaders.AUTHORIZATION, adminToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":5}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        verify(reviewService, never()).updateReview(any(), any());
    }

    /**
     * Updating another user's review surfaces the service's ownership {@code 403 REVIEW_FORBIDDEN}.
     */
    @Test
    void updateReviewOfAnotherUserReturns403() throws Exception {
        when(reviewService.updateReview(eq(55L), any()))
                .thenThrow(new BusinessException(HttpStatus.FORBIDDEN, "REVIEW_FORBIDDEN",
                        "You cannot access this review"));

        mockMvc.perform(put("/api/v1/reviews/55")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":5}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_FORBIDDEN"));
    }

    /**
     * Updating a review that does not exist surfaces the service's {@code 404 REVIEW_NOT_FOUND}.
     */
    @Test
    void updateReviewThatDoesNotExistReturns404() throws Exception {
        when(reviewService.updateReview(eq(55L), any()))
                .thenThrow(new ResourceNotFoundException("REVIEW_NOT_FOUND", "Review not found"));

        mockMvc.perform(put("/api/v1/reviews/55")
                        .header(HttpHeaders.AUTHORIZATION, customerToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rating\":5}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_NOT_FOUND"));
    }

    // ----- DELETE /reviews/{id} -----

    /**
     * {@code DELETE /reviews/{id}} as the owning CUSTOMER returns {@code 200 OK} with an empty payload.
     */
    @Test
    void deleteReviewAsCustomerReturns200() throws Exception {
        mockMvc.perform(delete("/api/v1/reviews/55").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        verify(reviewService).deleteReview(55L);
    }

    /**
     * A non-numeric id is a type mismatch rendered as the enveloped {@code 400 VALIDATION_ERROR}.
     */
    @Test
    void deleteReviewWithNonNumericIdReturns400() throws Exception {
        mockMvc.perform(delete("/api/v1/reviews/abc").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("VALIDATION_ERROR"));

        verify(reviewService, never()).deleteReview(any());
    }

    /**
     * An anonymous {@code DELETE /reviews/{id}} is denied the enveloped {@code 401}.
     */
    @Test
    void deleteReviewAnonymouslyReturns401() throws Exception {
        mockMvc.perform(delete("/api/v1/reviews/55"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("UNAUTHORIZED"));

        verify(reviewService, never()).deleteReview(any());
    }

    /**
     * {@code DELETE /reviews/{id}} with an ADMIN token is denied the enveloped {@code 403}: the review
     * writes are CUSTOMER-only.
     */
    @Test
    void deleteReviewAsAdminReturns403() throws Exception {
        mockMvc.perform(delete("/api/v1/reviews/55").header(HttpHeaders.AUTHORIZATION, adminToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("FORBIDDEN"));

        verify(reviewService, never()).deleteReview(any());
    }

    /**
     * Deleting another user's review surfaces the service's ownership {@code 403 REVIEW_FORBIDDEN}.
     */
    @Test
    void deleteReviewOfAnotherUserReturns403() throws Exception {
        org.mockito.Mockito.doThrow(new BusinessException(HttpStatus.FORBIDDEN, "REVIEW_FORBIDDEN",
                        "You cannot access this review"))
                .when(reviewService).deleteReview(55L);

        mockMvc.perform(delete("/api/v1/reviews/55").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_FORBIDDEN"));
    }

    /**
     * Deleting a review that does not exist surfaces the service's {@code 404 REVIEW_NOT_FOUND}.
     */
    @Test
    void deleteReviewThatDoesNotExistReturns404() throws Exception {
        org.mockito.Mockito.doThrow(new ResourceNotFoundException("REVIEW_NOT_FOUND", "Review not found"))
                .when(reviewService).deleteReview(55L);

        mockMvc.perform(delete("/api/v1/reviews/55").header(HttpHeaders.AUTHORIZATION, customerToken()))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorCode").value("REVIEW_NOT_FOUND"));
    }
}
