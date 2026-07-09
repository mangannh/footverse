package com.footverse.product.dto;

/**
 * A product image returned to clients (dto-spec §9).
 *
 * @param id           the image id
 * @param imageUrl     the image URL
 * @param displayOrder the ascending sort order
 * @param isPrimary    whether this is the product's primary image
 */
public record ProductImageResponse(
        Long id,
        String imageUrl,
        int displayOrder,
        boolean isPrimary) {
}
