package org.example.employeeshiftmanagement.exception;

import java.net.URI;

/**
 * Thrown when a well-formed request clashes with data that is already stored,
 * e.g. a shift that overlaps another of the same employee's shifts (F30) or
 * an email that another account already uses (B20).
 * ApiExceptionHandler answers 409 Conflict.
 *
 * Not 400: the request is valid on its own - sent a day earlier, before the
 * other shift existed, it would have succeeded. 409 tells the client that
 * fixing the stored data, not the form, is what resolves it.
 *
 * Deliberately general rather than ShiftOverlapException, so every such clash
 * shares one type and one status. The message is written for a person to
 * read, as with ResourceNotFoundException.
 *
 * A clash the client must tell apart from the others also carries a problem
 * type from ProblemTypes (B31); without one the body has no "type", which
 * means about:blank.
 */
public class ConflictException extends RuntimeException {

    private final URI type;

    public ConflictException(String message) {
        this(null, message);
    }

    public ConflictException(URI type, String message) {
        super(message);
        this.type = type;
    }

    /** One of ProblemTypes, or null for an ordinary clash. */
    public URI getType() {
        return type;
    }
}
