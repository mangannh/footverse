package com.footverse.product.dto;

import java.math.BigDecimal;

import com.footverse.product.entity.ProductVariantStatus;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * Admin request to create a product variant (validation-spec §12). The {@code (color, size)} pair
 * must be unique within the product.
 *
 * @param color         the variant color; required; at most 50 characters
 * @param size          the variant size; required
 * @param stockQuantity the stock on hand; required; zero or positive
 * @param sku           the stock-keeping unit; required; unique
 * @param priceOverride the optional price override; when null the product's base price applies
 * @param status        the variant status; required
 */
public record CreateProductVariantRequest(
        @NotBlank @Size(max = 50) String color,
        @NotBlank String size,
        @NotNull @Min(0) Integer stockQuantity,
        @NotBlank String sku,
        @Positive BigDecimal priceOverride,
        @NotNull ProductVariantStatus status) {
}
