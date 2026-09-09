package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;

import java.time.LocalDateTime;

/**
 * Body of PUT /api/v1/news/{id}. These four fields are exactly what
 * NewsItemService.updateNewsItem writes - the author and the type of an
 * existing item are not editable, and now the API says so.
 */
public record UpdateNewsRequest(
        @NotBlank(message = "Title is required")
        String title,

        @NotBlank(message = "Description is required")
        String description,

        LocalDateTime deadline,
        Integer targetValue
) {
}
