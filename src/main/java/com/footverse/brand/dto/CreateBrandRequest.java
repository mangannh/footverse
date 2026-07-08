package com.footverse.brand.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Payload for {@code POST /brands}. Validation follows validation-spec §12; the name's
 * uniqueness is a business rule enforced by the service, not a field-level constraint.
 *
 * @param name        required, the brand name (must be unique)
 * @param logoUrl     optional, at most 512 characters
 * @param description optional, at most 2000 characters
 */
public record CreateBrandRequest(
        @NotBlank String name,
        @Size(max = 512) String logoUrl,
        @Size(max = 2000) String description) {
}
