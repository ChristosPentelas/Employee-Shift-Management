package org.example.employeeshiftmanagement.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import org.example.employeeshiftmanagement.dto.ShiftRequest;

public class ValidShiftTimesValidator implements ConstraintValidator<ValidShiftTimes, ShiftRequest> {

    @Override
    public boolean isValid(ShiftRequest request, ConstraintValidatorContext context) {
        // A missing time is @NotNull's job, as in ValidLeaveDatesValidator.
        if (request == null || request.startTime() == null || request.endTime() == null) {
            return true;
        }

        if (!request.endTime().equals(request.startTime())) {
            return true;
        }

        // Reported on endTime so ApiExceptionHandler puts it in the errors map.
        context.disableDefaultConstraintViolation();
        context.buildConstraintViolationWithTemplate(context.getDefaultConstraintMessageTemplate())
                .addPropertyNode("endTime")
                .addConstraintViolation();
        return false;
    }
}
