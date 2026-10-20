package org.example.employeeshiftmanagement.exception;

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
 */
public class ConflictException extends RuntimeException {

    public ConflictException(String message) {
        super(message);
    }
}
