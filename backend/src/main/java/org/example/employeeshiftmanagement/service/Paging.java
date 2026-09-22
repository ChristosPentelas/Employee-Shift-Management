package org.example.employeeshiftmanagement.service;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/** Shared by every service that returns pages (F9). */
final class Paging {

    private Paging() {
    }

    /**
     * Keeps the page number and size the client asked for, but not its sort:
     * the order is the server's decision. A client-chosen sort could name any
     * entity field, including ones the response never shows - on users, that
     * would be {@code ?sort=password}.
     *
     * The sort passed in should end on a unique column (the id). Without one,
     * rows that tie may come back in a different order on each query, and a
     * row can then appear on two pages or on none.
     */
    static Pageable withSort(Pageable pageable, Sort sort) {
        return PageRequest.of(pageable.getPageNumber(), pageable.getPageSize(), sort);
    }
}
