package com.footverse.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when creating or updating a resource would violate a uniqueness constraint
 * (e.g. duplicate email, phone, name, code, or SKU). Rendered as HTTP {@code 409 Conflict}.
 */
public class DuplicateResourceException extends BusinessException {

    /**
     * Creates a duplicate-resource exception.
     *
     * @param errorCode the stable machine error code (e.g. {@code "USER_EMAIL_DUPLICATED"})
     * @param message   the user-safe message
     */
    public DuplicateResourceException(String errorCode, String message) {
        super(HttpStatus.CONFLICT, errorCode, message);
    }
}
