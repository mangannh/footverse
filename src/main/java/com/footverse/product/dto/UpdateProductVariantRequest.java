package com.footverse.product.dto;

import java.math.BigDecimal;

import com.footverse.product.entity.ProductVariantStatus;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * Admin request to update a product variant (validation-spec §12).
 *
 * @param size          the variant size; required; unique within the product
 * @param stockQuantity the stock on hand; required; zero or positive
 * @param sku           the stock-keeping unit; required; unique
 * @param priceOverride the optional price override; when null the product's base price applies
 * @param status        the variant status; required
 */
public record UpdateProductVariantRequest(
        @NotBlank String size,
        @NotNull @Min(0) Integer stockQuantity,
        @NotBlank String sku,
        @Positive BigDecimal priceOverride,
        @NotNull ProductVariantStatus status) {
}
