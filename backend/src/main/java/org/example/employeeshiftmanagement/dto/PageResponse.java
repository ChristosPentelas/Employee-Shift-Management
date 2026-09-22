package org.example.employeeshiftmanagement.dto;

import org.springframework.data.domain.Page;

import java.util.List;
import java.util.function.Function;

/**
 * One page of a list endpoint (F9). Our own shape rather than Spring's
 * {@code Page}, whose JSON is an internal detail of Spring Data that has
 * changed between versions - this record is the contract the app parses.
 *
 * <p>{@code page} is zero-based: the first page is {@code ?page=0}.
 */
public record PageResponse<T>(
        List<T> content,
        int page,
        int size,
        long totalElements,
        int totalPages
) {
    /** Maps each entity on the page to its DTO, so no entity leaves the controller. */
    public static <E, T> PageResponse<T> from(Page<E> page, Function<E, T> toDto) {
        return new PageResponse<>(
                page.getContent().stream().map(toDto).toList(),
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages()
        );
    }
}
