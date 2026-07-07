package com.footverse.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when an operation is not valid for the target's current state
 * (e.g. cancelling a non-PENDING order, a forbidden status transition, or deleting a
 * still-referenced resource). Rendered as HTTP {@code 409 Conflict}.
 */
public class InvalidOperationException extends BusinessException {

    /**
     * Creates an invalid-operation exception.
     *
     * @param errorCode the stable machine error code (e.g. {@code "ORDER_NOT_CANCELLABLE"})
     * @param message   the user-safe message
     */
    public InvalidOperationException(String errorCode, String message) {
        super(HttpStatus.CONFLICT, errorCode, message);
    }
}
