package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.example.employeeshiftmanagement.model.NewsType;

import java.time.LocalDateTime;

/**
 * Body of POST /api/v1/news.
 *
 * The author arrives as a flat id, not a nested {"author":{"id":n}} object: the
 * client is naming an existing user, not supplying one. There is also no
 * createdAt - NewsItem.onCreate() (@PrePersist) stamps that server-side, so a
 * client-sent value was only ever ignored.
 */
public record CreateNewsRequest(
        @NotBlank(message = "Title is required")
        String title,

        @NotBlank(message = "Description is required")
        String description,

        @NotNull(message = "Type is required")
        NewsType type,

        @NotNull(message = "Author is required")
        Integer authorId,

        LocalDateTime deadline,
        Integer targetValue
) {
}
