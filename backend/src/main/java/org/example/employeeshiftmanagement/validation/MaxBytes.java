package org.example.employeeshiftmanagement.validation;

import jakarta.validation.Constraint;
import jakarta.validation.Payload;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * A String may be at most {@code value} bytes long in UTF-8 (B20).
 *
 * Not @Size: @Size counts characters, and a Greek letter is one character
 * but two bytes. BCrypt's limit is in bytes, so a 50-letter Greek password
 * passes @Size(max = 72) at 100 bytes.
 *
 * On a field, unlike @ValidLeaveDates: the rule needs only the one value.
 */
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = MaxBytesValidator.class)
public @interface MaxBytes {

    int value();

    String message() default "must be at most {value} bytes";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};
}
