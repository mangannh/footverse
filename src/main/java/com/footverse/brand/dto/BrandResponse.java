package com.footverse.brand.dto;

/**
 * A product brand returned to clients (dto-spec §11).
 *
 * @param id          the brand id
 * @param name        the unique brand name
 * @param logoUrl     the logo URL, if any
 * @param description the description, if any
 */
public record BrandResponse(
        Long id,
        String name,
        String logoUrl,
        String description) {
}
