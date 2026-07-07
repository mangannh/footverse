package com.footverse.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when a referenced resource does not exist. Rendered as HTTP {@code 404 Not Found}.
 */
public class ResourceNotFoundException extends BusinessException {

    /**
     * Creates a not-found exception.
     *
     * @param errorCode the stable machine error code (e.g. {@code "PRODUCT_NOT_FOUND"})
     * @param message   the user-safe message
     */
    public ResourceNotFoundException(String errorCode, String message) {
        super(HttpStatus.NOT_FOUND, errorCode, message);
    }
}
