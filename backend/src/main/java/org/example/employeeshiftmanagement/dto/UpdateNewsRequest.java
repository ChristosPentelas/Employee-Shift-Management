package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.example.employeeshiftmanagement.validation.FieldLimits;

import java.time.LocalDateTime;

/**
 * Body of PUT /api/v1/news/{id}. These four fields are exactly what
 * NewsItemService.updateNewsItem writes - the author and the type of an
 * existing item are not editable, and now the API says so.
 */
public record UpdateNewsRequest(
        @NotBlank(message = "Title is required")
        @Size(max = FieldLimits.TEXT, message = "Title must be at most {max} characters")
        String title,

        @NotBlank(message = "Description is required")
        @Size(max = FieldLimits.TEXT, message = "Description must be at most {max} characters")
        String description,

        LocalDateTime deadline,
        Integer targetValue
) {
}
