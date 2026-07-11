package com.footverse.product.dto;

import java.math.BigDecimal;

import com.footverse.product.entity.ProductVariantStatus;

/**
 * A product variant returned to clients (dto-spec §9).
 *
 * @param id            the variant id
 * @param color         the color
 * @param size          the size
 * @param price         the effective price ({@code priceOverride}, or the product's
 *                      {@code basePrice} when {@code priceOverride} is null)
 * @param stockQuantity the available stock
 * @param status        the variant status
 * @param sku           the stock-keeping unit
 */
public record ProductVariantResponse(
        Long id,
        String color,
        String size,
        BigDecimal price,
        int stockQuantity,
        ProductVariantStatus status,
        String sku) {
}
