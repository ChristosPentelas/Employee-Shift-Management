package org.example.employeeshiftmanagement.exception;

/**
 * Thrown when a record the caller asked for does not exist.
 *
 * The class body is empty on purpose: its whole value is the type. Services
 * used to throw a plain RuntimeException for this, which a controller could
 * only catch together with every bug in the same method - so a missing user
 * and a NullPointerException came back as the same answer (F14).
 *
 * Unchecked (extends RuntimeException) because nothing between the service and
 * ApiExceptionHandler can do anything useful about it; making it checked would
 * force a try/catch into every layer in between, which is the problem F14 is
 * removing.
 */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }
}
