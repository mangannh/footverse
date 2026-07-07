package com.footverse.common.exception;

import org.springframework.http.HttpStatus;

import lombok.Getter;

/**
 * Base type for every domain error in the application.
 *
 * <p>A {@code BusinessException} carries a stable machine-readable {@code errorCode} and the
 * {@link HttpStatus} the API should return, so that {@link GlobalExceptionHandler} can render
 * the standard error envelope without any per-exception branching. Services throw it (or one
 * of its subclasses) and never build responses themselves.</p>
 */
@Getter
public class BusinessException extends RuntimeException {

    private final HttpStatus httpStatus;
    private final String errorCode;

    /**
     * Creates a business exception.
     *
     * @param httpStatus the HTTP status the API should return
     * @param errorCode  the stable, SCREAMING_SNAKE_CASE machine error code
     * @param message    the user-safe, human-readable message
     */
    public BusinessException(HttpStatus httpStatus, String errorCode, String message) {
        super(message);
        this.httpStatus = httpStatus;
        this.errorCode = errorCode;
    }
}
