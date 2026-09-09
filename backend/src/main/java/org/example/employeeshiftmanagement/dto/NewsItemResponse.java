package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;

import java.time.LocalDateTime;

/**
 * The "author" key nests a UserResponse rather than the User entity, which is
 * what keeps the author's password out of every news feed (F3).
 */
public record NewsItemResponse(
        Integer id,
        String title,
        String description,
        NewsType type,
        LocalDateTime createdAt,
        UserResponse author,
        LocalDateTime deadline,
        Integer targetValue
) {
    public static NewsItemResponse from(NewsItem item) {
        return new NewsItemResponse(
                item.getId(),
                item.getTitle(),
                item.getDescription(),
                item.getType(),
                item.getCreatedAt(),
                item.getAuthor() == null ? null : UserResponse.from(item.getAuthor()),
                item.getDeadline(),
                item.getTargetValue()
        );
    }
}
