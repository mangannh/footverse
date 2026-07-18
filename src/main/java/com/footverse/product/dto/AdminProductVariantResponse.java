package com.footverse.product.dto;

import java.math.BigDecimal;

import com.footverse.product.entity.ProductVariantStatus;

/**
 * A product variant returned to ADMIN (dto-spec §9), carrying the ADMIN-only {@code costPrice} and
 * the raw {@code priceOverride}. It is never returned by a public/customer endpoint; the public
 * {@link ProductVariantResponse} omits both (Sprint 11).
 *
 * <p>{@code priceOverride} is the raw entity value (as opposed to {@code price}, the resolved
 * effective value) so the ADMIN client can distinguish "no override — following {@code basePrice}"
 * from "explicit override" when editing a variant, without inferring that business state from a
 * price comparison (react-guidelines §Server Authoritative — the client never synthesizes server
 * state it was not given).</p>
 *
 * @param id            the variant id
 * @param color         the color
 * @param size          the size
 * @param price         the effective price ({@code priceOverride}, or the product's
 *                      {@code basePrice} when {@code priceOverride} is null)
 * @param priceOverride the raw override, or {@code null} when the variant follows {@code basePrice}
 * @param costPrice     the ADMIN-only unit cost basis
 * @param stockQuantity the available stock
 * @param status        the variant status
 * @param sku           the stock-keeping unit
 */
public record AdminProductVariantResponse(
        Long id,
        String color,
        String size,
        BigDecimal price,
        BigDecimal priceOverride,
        BigDecimal costPrice,
        int stockQuantity,
        ProductVariantStatus status,
        String sku) {
}
