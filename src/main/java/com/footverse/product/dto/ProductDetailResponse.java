package com.footverse.product.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Full product detail (dto-spec §9). A multi-source aggregate assembled by
 * {@code ProductService} from the product's own fields, its brand/category associations, its
 * images (sorted by {@code displayOrder}), and its variants.
 *
 * @param id            the product id
 * @param name          the product name
 * @param description   the description, or {@code null} when unset
 * @param basePrice     the base price
 * @param brandId       the owning brand's id
 * @param brandName     the owning brand's name
 * @param categoryId    the owning category's id
 * @param categoryName  the owning category's name
 * @param images        the images sorted by {@code displayOrder} ascending
 * @param variants      the variants, each carrying its effective price
 * @param averageRating the on-demand average rating (placeholder {@code 0.00} until the review
 *                      module lands)
 * @param reviewCount   the number of reviews (placeholder {@code 0} until the review module lands)
 * @param available     whether the product has at least one purchasable variant
 * @param createdAt     the creation timestamp
 */
public record ProductDetailResponse(
        Long id,
        String name,
        String description,
        BigDecimal basePrice,
        Long brandId,
        String brandName,
        Long categoryId,
        String categoryName,
        List<ProductImageResponse> images,
        List<ProductVariantResponse> variants,
        BigDecimal averageRating,
        int reviewCount,
        boolean available,
        LocalDateTime createdAt) {
}
