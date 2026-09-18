package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.example.employeeshiftmanagement.validation.FieldLimits;

/**
 * Body of POST /api/v1/messages. Sender and receiver are query parameters.
 *
 * Moved here from the model package: it was always a DTO, and living next to
 * the JPA entities was what made it easy to miss that the other four resources
 * had no DTO at all.
 */
public record MessageRequest(
        @NotBlank(message = "Content is required")
        @Size(max = FieldLimits.TEXT, message = "Content must be at most {max} characters")
        String content
) {
}
