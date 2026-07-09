package com.footverse.product.dto;

import java.math.BigDecimal;

/**
 * A compact product for list and search results (dto-spec §9). Assembled by
 * {@code ProductService} from the product, its brand/category associations, its primary image,
 * and its variants.
 *
 * @param id              the product id
 * @param name            the product name
 * @param basePrice       the base price
 * @param brandName       the owning brand's name
 * @param categoryName    the owning category's name
 * @param primaryImageUrl the URL of the primary image, or {@code null} when the product has none
 * @param averageRating   the on-demand average rating (placeholder {@code 0.00} until the review
 *                        module lands)
 * @param available       whether the product has at least one purchasable variant
 */
public record ProductSummaryResponse(
        Long id,
        String name,
        BigDecimal basePrice,
        String brandName,
        String categoryName,
        String primaryImageUrl,
        BigDecimal averageRating,
        boolean available) {
}
