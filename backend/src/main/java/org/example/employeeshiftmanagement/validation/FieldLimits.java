package org.example.employeeshiftmanagement.validation;

/**
 * Maximum lengths for request fields (F15).
 *
 * TEXT matches the column: the entities give their String fields no length,
 * so Hibernate creates every one as VARCHAR(255). Without a @Size on the DTO a
 * longer value reached MySQL, failed there, and came back as a 500 - the
 * server blaming itself for the caller's input.
 *
 * A constant rather than 255 written eleven times: an annotation attribute must
 * be a compile-time constant, and a static final int is one. If a column ever
 * grows (with a migration - see F8), this is the one place to change.
 */
public final class FieldLimits {

    public static final int TEXT = 255;

    private FieldLimits() {
    }
}
