package com.footverse.common.exception;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.NoHandlerFoundException;

import com.footverse.common.dto.ApiResponse;
import com.footverse.common.dto.FieldError;

import lombok.extern.slf4j.Slf4j;

/**
 * Single place that renders exceptions as the standard {@link ApiResponse} error envelope.
 *
 * <p>Controllers never catch exceptions and services never build responses; every error path
 * flows here and every envelope is built via {@link ApiResponse#error(String, String, List)}.
 * Handled here: {@link BusinessException} (and its subclasses), Bean Validation failures
 * ({@link MethodArgumentNotValidException}), unreadable request bodies
 * ({@link HttpMessageNotReadableException}), unknown-endpoint routing
 * ({@link NoHandlerFoundException}), and an unexpected-error fallback. Security error
 * formatting is added by its own task. No stack trace or internal detail is ever written to
 * the HTTP response.</p>
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * Renders a {@link BusinessException} (and its subclasses) using the exception's own HTTP
     * status and error code.
     *
     * @param ex the thrown business exception
     * @return the error envelope, at the exception's HTTP status
     */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusinessException(BusinessException ex) {
        log.warn("Business error [{}]: {}", ex.getErrorCode(), ex.getMessage());
        return ResponseEntity.status(ex.getHttpStatus())
                .body(ApiResponse.error(ex.getErrorCode(), ex.getMessage(), null));
    }

    /**
     * Renders a Bean Validation failure ({@code @Valid} on a request DTO) as a
     * {@code 400 VALIDATION_ERROR} envelope with one {@link FieldError} per offending field.
     *
     * @param ex the validation exception carrying the binding result
     * @return the error envelope with the field-level errors
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Void>> handleMethodArgumentNotValid(MethodArgumentNotValidException ex) {
        List<FieldError> errors = ex.getBindingResult().getFieldErrors().stream()
                .map(fieldError -> new FieldError(fieldError.getField(), fieldError.getDefaultMessage()))
                .toList();
        log.warn("Validation failed with {} field error(s)", errors.size());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error("VALIDATION_ERROR", "Validation failed", errors));
    }

    /**
     * Renders an unreadable or malformed request body as a {@code 400 VALIDATION_ERROR}
     * envelope without exposing parse details.
     *
     * @param ex the unreadable-message exception
     * @return the error envelope with no field-level errors
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleHttpMessageNotReadable(HttpMessageNotReadableException ex) {
        log.warn("Malformed request body");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(ApiResponse.error("VALIDATION_ERROR", "Malformed request body", null));
    }

    /**
     * Renders a request to an unmapped endpoint (routing 404) as the standard envelope.
     *
     * @param ex the no-handler-found exception
     * @return a {@code 404} envelope with error code {@code RESOURCE_NOT_FOUND}
     */
    @ExceptionHandler(NoHandlerFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNoHandlerFound(NoHandlerFoundException ex) {
        log.warn("No handler for {} {}", ex.getHttpMethod(), ex.getRequestURL());
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.error("RESOURCE_NOT_FOUND", "Resource not found", null));
    }

    /**
     * Fallback for any unexpected exception. The stack trace is logged server-side only; the
     * client receives a generic, user-safe {@code 500} envelope.
     *
     * @param ex the unhandled exception
     * @return a generic internal-error envelope
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpectedException(Exception ex) {
        log.error("Unexpected error", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ApiResponse.error("INTERNAL_ERROR", "An unexpected error occurred", null));
    }
}
