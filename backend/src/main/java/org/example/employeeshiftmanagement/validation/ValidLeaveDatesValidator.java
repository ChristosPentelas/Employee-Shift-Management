package org.example.employeeshiftmanagement.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import org.example.employeeshiftmanagement.dto.CreateLeaveRequest;

public class ValidLeaveDatesValidator implements ConstraintValidator<ValidLeaveDates, CreateLeaveRequest> {

    @Override
    public boolean isValid(CreateLeaveRequest request, ConstraintValidatorContext context) {
        // A missing date is @NotNull's job. Answering false here as well would
        // give the client two errors for one mistake.
        if (request == null || request.startDate() == null || request.endDate() == null) {
            return true;
        }

        // Same day is allowed: that is a one-day leave.
        if (!request.endDate().isBefore(request.startDate())) {
            return true;
        }

        // By default a class-level violation belongs to no field, and
        // ApiExceptionHandler only reports field errors - the client would get
        // "Validation failed" with nothing to point at. Re-attach it to endDate.
        context.disableDefaultConstraintViolation();
        context.buildConstraintViolationWithTemplate(context.getDefaultConstraintMessageTemplate())
                .addPropertyNode("endDate")
                .addConstraintViolation();
        return false;
    }
}
