package org.example.employeeshiftmanagement.exception;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Thrown by a service when a request breaks a rule that needs stored data to
 * check, e.g. an edit giving a task a target value: the edit carries no type,
 * only the stored item has it (B74). ApiExceptionHandler answers 400 with the
 * same body as a failed @Valid - "Validation failed" and an errors map of
 * field to message - so the client reads both alike.
 *
 * Not ConflictException's 409: that is for a request that would have worked
 * against other data, like a shift that overlaps one added since. A news
 * item's type never changes, so this request is wrong for that item at any
 * time - the form must change, not the stored data.
 */
public class FieldValidationException extends RuntimeException {

    private final Map<String, String> errors;

    public FieldValidationException(Map<String, String> errors) {
        super("Validation failed: " + errors);
        // A copy that keeps the caller's order and cannot be changed later.
        this.errors = Collections.unmodifiableMap(new LinkedHashMap<>(errors));
    }

    /** Field name to message, in the order the rule found them. */
    public Map<String, String> getErrors() {
        return errors;
    }
}
