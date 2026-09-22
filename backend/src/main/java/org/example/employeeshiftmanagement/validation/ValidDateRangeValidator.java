package org.example.employeeshiftmanagement.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import org.example.employeeshiftmanagement.dto.DateRangeQuery;

import java.time.temporal.ChronoUnit;

public class ValidDateRangeValidator implements ConstraintValidator<ValidDateRange, DateRangeQuery> {

    private String tooLongMessage;

    @Override
    public void initialize(ValidDateRange annotation) {
        this.tooLongMessage = annotation.tooLongMessage();
    }

    @Override
    public boolean isValid(DateRangeQuery range, ConstraintValidatorContext context) {
        // A missing date is @NotNull's job - see ValidLeaveDatesValidator.
        if (range == null || range.start() == null || range.end() == null) {
            return true;
        }

        if (range.end().isBefore(range.start())) {
            return rejectEnd(context, context.getDefaultConstraintMessageTemplate());
        }

        // Both days count: 2026-01-01 to 2026-01-01 is one day.
        long days = ChronoUnit.DAYS.between(range.start(), range.end()) + 1;
        if (days > ValidDateRange.MAX_DAYS) {
            return rejectEnd(context, tooLongMessage);
        }
        return true;
    }

    /** Reported on "end", so ApiExceptionHandler has a field to name. */
    private static boolean rejectEnd(ConstraintValidatorContext context, String message) {
        context.disableDefaultConstraintViolation();
        context.buildConstraintViolationWithTemplate(message)
                .addPropertyNode("end")
                .addConstraintViolation();
        return false;
    }
}
