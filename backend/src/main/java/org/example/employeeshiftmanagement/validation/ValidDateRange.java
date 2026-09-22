package org.example.employeeshiftmanagement.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * A date range must not end before it starts, and may cover at most
 * {@link #MAX_DAYS} days (F9).
 *
 * Without the cap, {@code ?start=1900-01-01&end=2999-12-31} is "give me every
 * shift ever" - the unbounded list F9 is about, reached through a filter.
 * A year and a day: enough for any calendar view, including a leap year.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidDateRangeValidator.class)
public @interface ValidDateRange {

    int MAX_DAYS = 366;

    String message() default "End date must not be before start date";

    String tooLongMessage() default "The range may cover at most " + MAX_DAYS + " days";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
