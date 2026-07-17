package com.footverse.review.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;

import com.footverse.common.dto.PageResponse;
import com.footverse.common.exception.BusinessException;
import com.footverse.common.exception.DuplicateResourceException;
import com.footverse.common.exception.ResourceNotFoundException;
import com.footverse.common.security.CurrentUserProvider;
import com.footverse.order.service.OrderService;
import com.footverse.review.dto.CreateReviewRequest;
import com.footverse.review.dto.RatingSummary;
import com.footverse.review.dto.ReviewResponse;
import com.footverse.review.dto.UpdateReviewRequest;
import com.footverse.review.entity.Review;
import com.footverse.review.mapper.ReviewMapper;
import com.footverse.review.repository.ReviewRatingSummary;
import com.footverse.review.repository.ReviewRepository;
import com.footverse.user.entity.User;

/**
 * Unit tests for {@link ReviewServiceImpl}: the forced newest-first listing order, the
 * eligibility gate and the duplicate guard on create (both the service-level
 * {@code existsByUserIdAndProductId} check and the unique-constraint race backstop), the
 * ownership 403/404 split on update and delete, and the on-demand rating aggregation
 * (scale/rounding, the empty case, and the batch read). Collaborators are mocked; the database
 * unique-constraint backstop's live behaviour is additionally exercised end-to-end by
 * {@code ReviewLifecycleIntegrationTest}.
 */
@ExtendWith(MockitoExtension.class)
class ReviewServiceImplTest {

    private static final Long PRODUCT_ID = 100L;
    private static final Long USER_ID = 7L;
    private static final Long REVIEW_ID = 55L;

    @Mock
    private ReviewRepository reviewRepository;

    @Mock
    private ReviewMapper reviewMapper;

    @Mock
    private OrderService orderService;

    @Mock
    private CurrentUserProvider currentUserProvider;

    private ReviewServiceImpl service;

    private void init() {
        service = new ReviewServiceImpl(reviewRepository, reviewMapper, orderService, currentUserProvider);
    }

    private User author() {
        User user = new User();
        user.setId(USER_ID);
        user.setFullName("Reviewer");
        user.setAvatarUrl("http://avatar");
        return user;
    }

    private Review review() {
        Review review = new Review();
        review.setId(REVIEW_ID);
        review.setUser(author());
        review.setProductId(PRODUCT_ID);
        review.setRating(4);
        review.setComment("Solid");
        return review;
    }

    private ReviewResponse response() {
        return new ReviewResponse(REVIEW_ID, PRODUCT_ID, USER_ID, "Reviewer", "http://avatar", 4, "Solid",
                LocalDateTime.now(), LocalDateTime.now());
    }

    private ReviewRatingSummary aggregate(Long productId, double average, long count) {
        ReviewRatingSummary summary = mock(ReviewRatingSummary.class);
        // Lenient: this shared projection builder stubs every getter, but the single-product path reads
        // only the average and count (not the product id), so strict stubbing would flag getProductId.
        lenient().when(summary.getProductId()).thenReturn(productId);
        lenient().when(summary.getAverageRating()).thenReturn(average);
        lenient().when(summary.getReviewCount()).thenReturn(count);
        return summary;
    }

    // ----- Public listing -----

    /**
     * The listing is always ordered {@code createdAt} descending: the service preserves the client's
     * page and size but overrides any client-supplied sort (assumption 4), and maps each row.
     */
    @Test
    void getProductReviewsForcesNewestFirstAndMapsRows() {
        init();
        Review review = review();
        when(reviewRepository.findByProductId(eq(PRODUCT_ID), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(review)));
        when(reviewMapper.toResponse(review)).thenReturn(response());

        PageResponse<ReviewResponse> page = service.getProductReviews(PRODUCT_ID,
                PageRequest.of(2, 5, Sort.by(Sort.Direction.ASC, "rating")));

        assertThat(page.content()).singleElement().extracting(ReviewResponse::id).isEqualTo(REVIEW_ID);
        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(reviewRepository).findByProductId(eq(PRODUCT_ID), pageable.capture());
        Pageable used = pageable.getValue();
        assertThat(used.getPageNumber()).isEqualTo(2);
        assertThat(used.getPageSize()).isEqualTo(5);
        Sort.Order createdAt = used.getSort().getOrderFor("createdAt");
        assertThat(createdAt).isNotNull();
        assertThat(createdAt.getDirection()).isEqualTo(Sort.Direction.DESC);
        assertThat(used.getSort().getOrderFor("rating")).isNull();
    }

    /**
     * An unknown product (or one with no reviews) yields an empty page, never a {@code 404}
     * (assumption 5).
     */
    @Test
    void getProductReviewsForUnknownProductReturnsEmptyPage() {
        init();
        when(reviewRepository.findByProductId(eq(999L), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        PageResponse<ReviewResponse> page = service.getProductReviews(999L, PageRequest.of(0, 20));

        assertThat(page.content()).isEmpty();
        verifyNoInteractions(reviewMapper);
    }

    // ----- Create: eligibility gate + duplicate guard -----

    private CreateReviewRequest createRequest() {
        return new CreateReviewRequest(PRODUCT_ID, 4, "Solid");
    }

    /**
     * An eligible, first-time review is stamped to the caller and persisted with the requested
     * rating and comment, then mapped to the response.
     */
    @Test
    void createReviewEligibleAndNotDuplicatePersistsForCaller() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(orderService.hasDeliveredOrderForProduct(PRODUCT_ID)).thenReturn(true);
        when(reviewRepository.existsByUserIdAndProductId(USER_ID, PRODUCT_ID)).thenReturn(false);
        when(reviewRepository.saveAndFlush(any(Review.class))).thenAnswer(inv -> inv.getArgument(0));
        when(reviewMapper.toResponse(any(Review.class))).thenReturn(response());

        ReviewResponse result = service.createReview(createRequest());

        assertThat(result).isNotNull();
        ArgumentCaptor<Review> captor = ArgumentCaptor.forClass(Review.class);
        verify(reviewRepository).saveAndFlush(captor.capture());
        Review saved = captor.getValue();
        assertThat(saved.getUser().getId()).isEqualTo(USER_ID);
        assertThat(saved.getProductId()).isEqualTo(PRODUCT_ID);
        assertThat(saved.getRating()).isEqualTo(4);
        assertThat(saved.getComment()).isEqualTo("Solid");
    }

    /**
     * A caller with no {@code DELIVERED} order containing the product is rejected with
     * {@code 403 REVIEW_NOT_ELIGIBLE}; the duplicate check never runs and nothing is persisted.
     */
    @Test
    void createReviewWhenIneligibleThrowsForbiddenAndWritesNothing() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(orderService.hasDeliveredOrderForProduct(PRODUCT_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.createReview(createRequest()))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REVIEW_NOT_ELIGIBLE")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.FORBIDDEN);
        verify(reviewRepository, never()).existsByUserIdAndProductId(any(), any());
        verify(reviewRepository, never()).saveAndFlush(any());
    }

    /**
     * The service-level duplicate guard: an eligible caller who already reviewed the product is
     * rejected with {@code 409 REVIEW_DUPLICATED} before any insert.
     */
    @Test
    void createReviewWhenAlreadyReviewedThrowsConflictAtServiceLayer() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(orderService.hasDeliveredOrderForProduct(PRODUCT_ID)).thenReturn(true);
        when(reviewRepository.existsByUserIdAndProductId(USER_ID, PRODUCT_ID)).thenReturn(true);

        assertThatThrownBy(() -> service.createReview(createRequest()))
                .isInstanceOf(DuplicateResourceException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REVIEW_DUPLICATED")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.CONFLICT);
        verify(reviewRepository, never()).saveAndFlush(any());
    }

    /**
     * The database backstop: a review that passes the service guard but loses a race and trips the
     * {@code uk_review_user_id_product_id} unique constraint is translated to the same enveloped
     * {@code 409 REVIEW_DUPLICATED}, never a leaked {@code 500}.
     */
    @Test
    void createReviewTranslatesUniqueViolationToConflict() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(orderService.hasDeliveredOrderForProduct(PRODUCT_ID)).thenReturn(true);
        when(reviewRepository.existsByUserIdAndProductId(USER_ID, PRODUCT_ID)).thenReturn(false);
        when(reviewRepository.saveAndFlush(any(Review.class)))
                .thenThrow(new DataIntegrityViolationException("uk_review_user_id_product_id"));

        assertThatThrownBy(() -> service.createReview(createRequest()))
                .isInstanceOf(DuplicateResourceException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REVIEW_DUPLICATED")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.CONFLICT);
    }

    // ----- Update: ownership split -----

    private UpdateReviewRequest updateRequest() {
        return new UpdateReviewRequest(5, "Even better");
    }

    /**
     * The owner can update rating and comment; the persisted review carries the new values and is
     * mapped to the response.
     */
    @Test
    void updateReviewByOwnerChangesRatingAndComment() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        Review review = review();
        when(reviewRepository.findByIdAndUserId(REVIEW_ID, USER_ID)).thenReturn(Optional.of(review));
        when(reviewRepository.saveAndFlush(review)).thenReturn(review);
        when(reviewMapper.toResponse(review)).thenReturn(response());

        service.updateReview(REVIEW_ID, updateRequest());

        assertThat(review.getRating()).isEqualTo(5);
        assertThat(review.getComment()).isEqualTo("Even better");
        verify(reviewRepository).saveAndFlush(review);
    }

    /**
     * A review that exists but belongs to another user is the ownership {@code 403 REVIEW_FORBIDDEN}
     * — never hidden behind a {@code 404}; nothing is persisted.
     */
    @Test
    void updateReviewOfAnotherUserIsForbidden() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(reviewRepository.findByIdAndUserId(REVIEW_ID, USER_ID)).thenReturn(Optional.empty());
        when(reviewRepository.existsById(REVIEW_ID)).thenReturn(true);

        assertThatThrownBy(() -> service.updateReview(REVIEW_ID, updateRequest()))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REVIEW_FORBIDDEN")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.FORBIDDEN);
        verify(reviewRepository, never()).saveAndFlush(any());
    }

    /**
     * A review that does not exist at all is the {@code 404 REVIEW_NOT_FOUND}.
     */
    @Test
    void updateReviewThatDoesNotExistIsNotFound() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(reviewRepository.findByIdAndUserId(REVIEW_ID, USER_ID)).thenReturn(Optional.empty());
        when(reviewRepository.existsById(REVIEW_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.updateReview(REVIEW_ID, updateRequest()))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REVIEW_NOT_FOUND")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.NOT_FOUND);
    }

    // ----- Delete: ownership split -----

    /**
     * The owner can permanently delete their review.
     */
    @Test
    void deleteReviewByOwnerRemovesIt() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        Review review = review();
        when(reviewRepository.findByIdAndUserId(REVIEW_ID, USER_ID)).thenReturn(Optional.of(review));

        service.deleteReview(REVIEW_ID);

        verify(reviewRepository).delete(review);
    }

    /**
     * Deleting another user's review is the ownership {@code 403 REVIEW_FORBIDDEN}; nothing is removed.
     */
    @Test
    void deleteReviewOfAnotherUserIsForbidden() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(reviewRepository.findByIdAndUserId(REVIEW_ID, USER_ID)).thenReturn(Optional.empty());
        when(reviewRepository.existsById(REVIEW_ID)).thenReturn(true);

        assertThatThrownBy(() -> service.deleteReview(REVIEW_ID))
                .isInstanceOf(BusinessException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REVIEW_FORBIDDEN")
                .hasFieldOrPropertyWithValue("httpStatus", HttpStatus.FORBIDDEN);
        verify(reviewRepository, never()).delete(any());
    }

    /**
     * Deleting a review that does not exist is the {@code 404 REVIEW_NOT_FOUND}.
     */
    @Test
    void deleteReviewThatDoesNotExistIsNotFound() {
        init();
        when(currentUserProvider.getCurrentUser()).thenReturn(author());
        when(reviewRepository.findByIdAndUserId(REVIEW_ID, USER_ID)).thenReturn(Optional.empty());
        when(reviewRepository.existsById(REVIEW_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.deleteReview(REVIEW_ID))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasFieldOrPropertyWithValue("errorCode", "REVIEW_NOT_FOUND");
        verify(reviewRepository, never()).delete(any());
    }

    // ----- Rating aggregation: single -----

    /**
     * A single-product summary normalizes the raw floating-point {@code AVG} to scale 2 and narrows
     * the count.
     */
    @Test
    void getRatingSummaryNormalizesAverageAndCount() {
        init();
        ReviewRatingSummary aggregate = aggregate(PRODUCT_ID, 4.666666, 3);
        when(reviewRepository.findRatingSummaryByProductId(PRODUCT_ID)).thenReturn(Optional.of(aggregate));

        RatingSummary summary = service.getRatingSummary(PRODUCT_ID);

        assertThat(summary.averageRating()).isEqualByComparingTo("4.67");
        assertThat(summary.reviewCount()).isEqualTo(3);
    }

    /**
     * The average rounds {@code HALF_UP} at the scale-2 boundary (assumption 6): a raw {@code 2.125}
     * becomes {@code 2.13}, not {@code 2.12}.
     */
    @Test
    void getRatingSummaryRoundsHalfUpAtBoundary() {
        init();
        ReviewRatingSummary aggregate = aggregate(PRODUCT_ID, 2.125, 4);
        when(reviewRepository.findRatingSummaryByProductId(PRODUCT_ID)).thenReturn(Optional.of(aggregate));

        RatingSummary summary = service.getRatingSummary(PRODUCT_ID);

        assertThat(summary.averageRating()).isEqualByComparingTo("2.13");
    }

    /**
     * A product with no reviews yields the shared empty aggregate {@code 0.00} / {@code 0}.
     */
    @Test
    void getRatingSummaryForUnreviewedProductIsEmptyAggregate() {
        init();
        when(reviewRepository.findRatingSummaryByProductId(PRODUCT_ID)).thenReturn(Optional.empty());

        RatingSummary summary = service.getRatingSummary(PRODUCT_ID);

        assertThat(summary.averageRating()).isEqualByComparingTo("0.00");
        assertThat(summary.reviewCount()).isZero();
        assertThat(summary).isEqualTo(RatingSummary.empty());
    }

    // ----- Rating aggregation: batch -----

    /**
     * The batch summary reads every product's aggregate in one query and keys the normalized results
     * by product id; a product absent from the aggregate simply has no entry (its consumer supplies
     * the {@code 0.00} / {@code 0} fallback).
     */
    @Test
    void getRatingSummariesAggregatesManyProductsInOneQuery() {
        init();
        List<Long> ids = List.of(PRODUCT_ID, 200L, 300L);
        ReviewRatingSummary first = aggregate(PRODUCT_ID, 5.0, 2);
        ReviewRatingSummary second = aggregate(200L, 3.5, 4);
        when(reviewRepository.findRatingSummariesByProductIdIn(ids)).thenReturn(List.of(first, second));

        Map<Long, RatingSummary> summaries = service.getRatingSummaries(ids);

        assertThat(summaries).containsOnlyKeys(PRODUCT_ID, 200L);
        assertThat(summaries.get(PRODUCT_ID).averageRating()).isEqualByComparingTo("5.00");
        assertThat(summaries.get(PRODUCT_ID).reviewCount()).isEqualTo(2);
        assertThat(summaries.get(200L).averageRating()).isEqualByComparingTo("3.50");
        assertThat(summaries).doesNotContainKey(300L);
        verify(reviewRepository).findRatingSummariesByProductIdIn(ids);
    }

    /**
     * An empty id collection short-circuits with no query at all — the batch read never fires.
     */
    @Test
    void getRatingSummariesWithEmptyCollectionQueriesNothing() {
        init();

        assertThat(service.getRatingSummaries(List.of())).isEmpty();
        verify(reviewRepository, never()).findRatingSummariesByProductIdIn(any());
    }
}
