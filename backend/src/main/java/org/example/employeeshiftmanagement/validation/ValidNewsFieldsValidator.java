package org.example.employeeshiftmanagement.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import org.example.employeeshiftmanagement.dto.CreateNewsRequest;
import org.example.employeeshiftmanagement.model.NewsType;

public class ValidNewsFieldsValidator implements ConstraintValidator<ValidNewsFields, CreateNewsRequest> {

    @Override
    public boolean isValid(CreateNewsRequest request, ConstraintValidatorContext context) {
        // A missing type is @NotNull's job, as in ValidLeaveDatesValidator.
        if (request == null || request.type() == null) {
            return true;
        }

        boolean deadlineFits = request.deadline() == null || request.type() == NewsType.TASK;
        boolean targetFits = request.targetValue() == null || request.type() == NewsType.GOAL;
        if (deadlineFits && targetFits) {
            return true;
        }

        // One violation per field that does not belong, each on that field,
        // so ApiExceptionHandler puts both in the errors map when both are
        // wrong - one mistake per round trip would make the client guess.
        context.disableDefaultConstraintViolation();
        if (!deadlineFits) {
            context.buildConstraintViolationWithTemplate("Only a task can have a deadline")
                    .addPropertyNode("deadline")
                    .addConstraintViolation();
        }
        if (!targetFits) {
            context.buildConstraintViolationWithTemplate("Only a goal can have a target value")
                    .addPropertyNode("targetValue")
                    .addConstraintViolation();
        }
        return false;
    }
}
