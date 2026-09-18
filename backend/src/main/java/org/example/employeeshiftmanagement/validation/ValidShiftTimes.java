package org.example.employeeshiftmanagement.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * A shift must not start and end at the same time (F15).
 *
 * An end time earlier than the start time is allowed on purpose: it is an
 * overnight shift that ends the next day (22:00 - 06:00), decided 2026-09-18.
 * So "end after start" would be the wrong rule here - only equal times are
 * impossible, a shift of zero hours or of exactly 24.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidShiftTimesValidator.class)
public @interface ValidShiftTimes {

    String message() default "End time must differ from start time";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
