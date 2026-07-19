package com.footverse.order.dto;

import java.math.BigDecimal;

/**
 * One row of the ADMIN dashboard's best-selling products (dto-spec §15, Sprint 13), folded from
 * per-variant sales up to product level — the repository aggregates by
 * {@code order_item.product_variant_id} (the only key it stores), and the service resolves each
 * variant to its owning product through {@code ProductVariantService} before summing quantities and
 * revenue per product (Design Decision 10). Grouping by the snapshotted product name instead would be
 * wrong: a renamed product would split into two rows, and two products that ever shared a name would
 * merge into one.
 *
 * @param productId       the product id
 * @param productName     the product name
 * @param productImageUrl the product's primary image URL, or {@code null} when it has none
 * @param quantitySold    the sum of order-item quantities across the product's variants, over
 *                        {@code DELIVERED} orders only
 * @param revenue         the sum of order-item {@code lineTotal} across the product's variants, over
 *                        {@code DELIVERED} orders only
 */
public record BestSellingProductResponse(
        Long productId,
        String productName,
        String productImageUrl,
        int quantitySold,
        BigDecimal revenue) {
}
