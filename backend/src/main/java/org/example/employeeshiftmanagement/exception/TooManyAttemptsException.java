package org.example.employeeshiftmanagement.exception;

import java.time.Duration;

/**
 * Thrown when an account is locked after too many failed passwords (B56).
 * ApiExceptionHandler answers 429 Too Many Requests, with a Retry-After header
 * saying how long the lock has left.
 *
 * Not 401: the app ends the session on any 401 to a request that carried a
 * token (auth_client.dart), and it needs to tell "wait" apart from "wrong
 * password".
 *
 * No constructor that takes a message, like InvalidCredentialsException: the
 * text is fixed, so no email can ever end up in it.
 */
public class TooManyAttemptsException extends RuntimeException {

    private final Duration retryAfter;

    public TooManyAttemptsException(Duration retryAfter) {
        super("Too many failed attempts, try again later");
        this.retryAfter = retryAfter;
    }

    /** How long until the lock ends. */
    public Duration getRetryAfter() {
        return retryAfter;
    }
}
