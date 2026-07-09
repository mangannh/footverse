package com.footverse.product.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * Admin request to create a product image (validation-spec §12). When {@code isPrimary} is true
 * the service clears the product's previous primary so exactly one primary remains
 * (architecture-spec §13).
 *
 * @param imageUrl     the image URL; required
 * @param displayOrder the ascending sort order; required; zero or positive
 * @param isPrimary    whether this image is the product's primary; required
 */
public record CreateProductImageRequest(
        @NotBlank @Size(max = 512) String imageUrl,
        @NotNull @Min(0) Integer displayOrder,
        @NotNull Boolean isPrimary) {
}
