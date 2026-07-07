package com.footverse.common.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Standard success/error envelope wrapping every API response.
 *
 * <p>Success responses are built via the {@link #ok(Object)} and {@link #created(Object)}
 * static factories. The error fields ({@code errorCode}, {@code errors}) are populated only
 * on failure responses and are omitted from the serialized JSON when {@code null}.</p>
 *
 * @param <T>       the payload type
 * @param success   {@code true} on success, {@code false} on error
 * @param message   human-readable message (e.g. {@code "OK"})
 * @param data      the payload; {@code null} on error or when there is no body
 * @param errorCode machine-readable error code; present on error responses only
 * @param errors    field-level validation errors; present on validation failures only
 * @param timestamp server timestamp of the response
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(
        boolean success,
        String message,
        T data,
        String errorCode,
        List<FieldError> errors,
        LocalDateTime timestamp) {

    /**
     * Builds a success envelope for a {@code 200 OK} response.
     *
     * @param data the response payload (may be {@code null} for empty bodies)
     * @param <T>  the payload type
     * @return a success envelope carrying the message {@code "OK"}
     */
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, "OK", data, null, null, LocalDateTime.now());
    }

    /**
     * Builds a success envelope for a {@code 201 Created} response.
     *
     * @param data the created resource payload
     * @param <T>  the payload type
     * @return a success envelope carrying the message {@code "Created"}
     */
    public static <T> ApiResponse<T> created(T data) {
        return new ApiResponse<>(true, "Created", data, null, null, LocalDateTime.now());
    }

    /**
     * Builds a failure envelope. This is the single construction path for every error
     * response; the {@code GlobalExceptionHandler} uses it instead of the constructor.
     *
     * @param errorCode the machine-readable error code
     * @param message   the user-safe message
     * @param errors    field-level validation errors, or {@code null} when not applicable
     * @param <T>       the payload type (data is always {@code null} for errors)
     * @return a failure envelope with {@code success = false} and no data
     */
    public static <T> ApiResponse<T> error(String errorCode, String message, List<FieldError> errors) {
        return new ApiResponse<>(false, message, null, errorCode, errors, LocalDateTime.now());
    }
}
