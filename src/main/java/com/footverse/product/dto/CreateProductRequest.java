package com.footverse.product.dto;

import java.math.BigDecimal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * Admin request to create a product (validation-spec §12). Existence of {@code categoryId} /
 * {@code brandId} is a business validation enforced in the service; the base price must be
 * positive.
 *
 * @param name        the product name; required
 * @param description the description; optional
 * @param basePrice   the base price; required; strictly positive
 * @param categoryId  the owning category id; required; must exist
 * @param brandId     the owning brand id; required; must exist
 */
public record CreateProductRequest(
        @NotBlank String name,
        @Size(max = 2000) String description,
        @NotNull @Positive BigDecimal basePrice,
        @NotNull @Positive Long categoryId,
        @NotNull @Positive Long brandId) {
}
