package com.footverse.product.dto;

import java.math.BigDecimal;

/**
 * A compact product for the ADMIN management list (dto-spec §9, {@code GET /admin/products}). A
 * dedicated ADMIN DTO — the public catalog {@code ProductSummaryResponse} is never reused for ADMIN
 * reads, keeping the two contracts isolated (Sprint 11). It carries no per-variant {@code costPrice}
 * (cost is variant-level; see {@link AdminProductVariantResponse}).
 *
 * @param id              the product id
 * @param name            the product name
 * @param basePrice       the base price
 * @param brandName       the owning brand's name
 * @param categoryName    the owning category's name
 * @param primaryImageUrl the URL of the primary image, or {@code null} when the product has none
 * @param averageRating   the on-demand average rating
 * @param available       whether the product has at least one purchasable variant
 */
public record AdminProductSummaryResponse(
        Long id,
        String name,
        BigDecimal basePrice,
        String brandName,
        String categoryName,
        String primaryImageUrl,
        BigDecimal averageRating,
        boolean available) {
}
