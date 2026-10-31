package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.exception.FieldValidationException;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.repository.NewsItemRepository;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Plain unit tests for how the news list is paged and what an edit may
 * change: no Spring, no Docker.
 */
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

    /** A stored item of [type], with id 1, as the repository returns it. */
    private NewsItem stored(NewsType type) {
        NewsItem item = new NewsItem();
        item.setId(1);
        item.setTitle("Inventory");
        item.setDescription("Count the stock");
        item.setType(type);
        when(newsItemRepository.findById(1)).thenReturn(Optional.of(item));
        return item;
    }

    /** What PUT /news/1 hands the service: the four editable fields. */
    private static NewsItem edit(LocalDateTime deadline, Integer targetValue) {
        NewsItem details = new NewsItem();
        details.setTitle("Inventory, again");
        details.setDescription("Count the stock twice");
        details.setDeadline(deadline);
        details.setTargetValue(targetValue);
        return details;
    }

    // B74: an edit carries no type - the type cannot be changed - so the
    // request alone cannot be checked; the stored item decides.
    @Test
    void editingATaskToHaveATargetValueIsRefusedAndChangesNothing() {
        NewsItem task = stored(NewsType.TASK);

        FieldValidationException refused = assertThrows(FieldValidationException.class,
                () -> newsItemService.updateNewsItem(edit(null, 50), 1));

        assertEquals(Map.of("targetValue", "Only a goal can have a target value"),
                refused.getErrors());
        verify(newsItemRepository, never()).save(any());
        // Checked before anything is set: a changed entity inside a
        // transaction can still be written at commit.
        assertEquals("Inventory", task.getTitle());
        assertNull(task.getTargetValue());
    }

    @Test
    void editingAGoalToHaveADeadlineIsRefused() {
        stored(NewsType.GOAL);

        FieldValidationException refused = assertThrows(FieldValidationException.class,
                () -> newsItemService.updateNewsItem(
                        edit(LocalDateTime.of(2026, 11, 30, 0, 0), 50), 1));

        assertEquals(Map.of("deadline", "Only a task can have a deadline"), refused.getErrors());
        verify(newsItemRepository, never()).save(any());
    }

    // Passes before the rule as well: it guards against refusing a type its
    // own extra.
    @Test
    void editingATasksDeadlineIsSaved() {
        NewsItem task = stored(NewsType.TASK);
        when(newsItemRepository.save(task)).thenReturn(task);
        LocalDateTime later = LocalDateTime.of(2026, 12, 15, 0, 0);

        newsItemService.updateNewsItem(edit(later, null), 1);

        verify(newsItemRepository).save(task);
        assertEquals(later, task.getDeadline());
        assertEquals("Inventory, again", task.getTitle());
    }
}
