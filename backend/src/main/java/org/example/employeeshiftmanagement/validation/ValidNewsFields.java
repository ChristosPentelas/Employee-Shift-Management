package org.example.employeeshiftmanagement.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Each news type has at most its own extra field (B74): only a TASK has a
 * deadline and only a GOAL a target value. An ANNOUNCEMENT has neither.
 *
 * Neither is required - a goal without a target or a task without a deadline
 * is allowed, decided 2026-10-31. Only the wrong pairing is refused.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidNewsFieldsValidator.class)
public @interface ValidNewsFields {

    // Never shown: the validator reports each field with its own message.
    String message() default "Fields do not match the news type";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
