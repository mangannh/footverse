package com.footverse.common.dto;

/**
 * A single field-level validation error, as carried by {@link ApiResponse#errors()}.
 *
 * @param field   the name of the offending field
 * @param message the human-readable validation message
 */
public record FieldError(String field, String message) {
}
