package org.example.employeeshiftmanagement.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * A leave request must not end before it starts (F15).
 *
 * Class-level, not on a field: @NotNull on endDate can only see endDate, but
 * this rule compares two fields, so it has to be given the whole object.
 * The error is still reported on endDate - see ValidLeaveDatesValidator.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidLeaveDatesValidator.class)
public @interface ValidLeaveDates {

    String message() default "End date must not be before start date";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
