package org.example.employeeshiftmanagement;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.util.List;

/** What a mocked service hands back from a paged method (F9): page 0, 20 per page. */
final class TestPages {

    private TestPages() {
    }

    @SafeVarargs
    static <T> Page<T> of(T... items) {
        return new PageImpl<>(List.of(items), PageRequest.of(0, 20), items.length);
    }
}
