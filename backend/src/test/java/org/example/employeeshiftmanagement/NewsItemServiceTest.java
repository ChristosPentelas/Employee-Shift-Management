package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.repository.NewsItemRepository;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Plain unit test for how the news list is paged: no Spring, no Docker. */
class NewsItemServiceTest {

    private final NewsItemRepository newsItemRepository = mock(NewsItemRepository.class);
    private final NewsItemService newsItemService =
            new NewsItemService(newsItemRepository, mock(UserService.class));

    @Test
    void theClientsPageIsKeptButItsSortIsReplaced() {
        when(newsItemRepository.findAll(any(Pageable.class))).thenReturn(Page.empty());

        // As if the client sent ?page=3&size=10&sort=title,asc
        newsItemService.getAllNews(PageRequest.of(3, 10, Sort.by("title")));

        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(newsItemRepository).findAll(captor.capture());
        Pageable used = captor.getValue();
        assertEquals(3, used.getPageNumber());
        assertEquals(10, used.getPageSize());
        assertEquals(Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")), used.getSort());
    }
}
