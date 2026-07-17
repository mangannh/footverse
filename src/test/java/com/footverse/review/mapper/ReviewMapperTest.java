package com.footverse.review.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.footverse.review.dto.ReviewResponse;
import com.footverse.review.entity.Review;
import com.footverse.user.entity.User;

/**
 * Unit test for the generated {@link ReviewMapper}. It proves the pure single-entity mapping maps the
 * item-01 additive fields — {@code productId} from the review's plain {@code productId} value and
 * {@code userId} from the review's {@code user} reference — alongside the existing author display
 * fields, with no service or repository call (architecture-spec §9).
 */
class ReviewMapperTest {

    private final ReviewMapper mapper = new ReviewMapperImpl();

    /**
     * A review maps to its response with the new {@code productId} / {@code userId} carried from the
     * entity, and every previously-mapped field unchanged.
     */
    @Test
    void toResponseMapsProductIdAndUserIdAlongsideAuthorDisplayFields() {
        User author = new User();
        author.setId(7L);
        author.setFullName("Reviewer");
        author.setAvatarUrl("http://avatar");
        Review review = new Review();
        review.setId(55L);
        review.setUser(author);
        review.setProductId(100L);
        review.setRating(4);
        review.setComment("Solid");

        ReviewResponse response = mapper.toResponse(review);

        assertThat(response.id()).isEqualTo(55L);
        assertThat(response.productId()).isEqualTo(100L);
        assertThat(response.userId()).isEqualTo(7L);
        assertThat(response.userFullName()).isEqualTo("Reviewer");
        assertThat(response.userAvatarUrl()).isEqualTo("http://avatar");
        assertThat(response.rating()).isEqualTo(4);
        assertThat(response.comment()).isEqualTo("Solid");
    }
}
