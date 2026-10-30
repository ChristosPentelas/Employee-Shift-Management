package org.example.employeeshiftmanagement.validation;

import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import org.example.employeeshiftmanagement.dto.CreateNewsRequest;

import java.util.Map;

public class ValidNewsFieldsValidator implements ConstraintValidator<ValidNewsFields, CreateNewsRequest> {

    @Override
    public boolean isValid(CreateNewsRequest request, ConstraintValidatorContext context) {
        if (request == null) {
            return true;
        }

        // The rule itself is in NewsFieldRules, shared with editing a post.
        Map<String, String> mismatches =
                NewsFieldRules.mismatches(request.type(), request.deadline(), request.targetValue());
        if (mismatches.isEmpty()) {
            return true;
        }

        // One violation per field that does not belong, each on that field,
        // so ApiExceptionHandler puts both in the errors map when both are
        // wrong - one mistake per round trip would make the client guess.
        context.disableDefaultConstraintViolation();
        mismatches.forEach((field, message) ->
                context.buildConstraintViolationWithTemplate(message)
                        .addPropertyNode(field)
                        .addConstraintViolation());
        return false;
    }
}
