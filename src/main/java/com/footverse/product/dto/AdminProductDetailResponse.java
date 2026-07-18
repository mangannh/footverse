package com.footverse.product.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Full product detail for ADMIN (dto-spec §9, {@code GET /admin/products/{id}}). Mirrors
 * {@link ProductDetailResponse}, but its {@code variants} are {@link AdminProductVariantResponse}
 * (carrying {@code costPrice}); its {@code images} reuse the non-sensitive
 * {@link ProductImageResponse} (Sprint 11). Assembled by {@code ProductService}.
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
 * @param variants      the variants, each carrying its effective price and ADMIN-only cost price
 * @param averageRating the on-demand average rating
 * @param reviewCount   the number of reviews
 * @param available     whether the product has at least one purchasable variant
 * @param createdAt     the creation timestamp
 */
public record AdminProductDetailResponse(
        Long id,
        String name,
        String description,
        BigDecimal basePrice,
        Long brandId,
        String brandName,
        Long categoryId,
        String categoryName,
        List<ProductImageResponse> images,
        List<AdminProductVariantResponse> variants,
        BigDecimal averageRating,
        int reviewCount,
        boolean available,
        LocalDateTime createdAt) {
}
