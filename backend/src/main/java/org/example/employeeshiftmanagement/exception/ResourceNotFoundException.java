package org.example.employeeshiftmanagement.exception;

/**
 * Thrown when a record the caller asked for does not exist.
 *
 * Services used to throw a plain RuntimeException for this, which a controller
 * could only catch together with every bug in the same method - so a missing
 * user and a NullPointerException came back as the same answer (F14).
 *
 * The message is the "detail" of the 404 body, so it is part of the API. It is
 * built here, from the resource's name and the id the caller asked for, rather
 * than written out at each throw site: when every site wrote its own, they
 * drifted into five wordings (B22).
 *
 * Unchecked (extends RuntimeException) because nothing between the service and
 * ApiExceptionHandler can do anything useful about it; making it checked would
 * force a try/catch into every layer in between, which is the problem F14 is
 * removing.
 */
public class ResourceNotFoundException extends RuntimeException {

    /**
     * @param resource what was looked for, in sentence case: "User", "News item"
     * @param id       what the caller looked it up by, usually the id
     */
    public ResourceNotFoundException(String resource, Object id) {
        super(resource + " not found: " + id);
    }
}
