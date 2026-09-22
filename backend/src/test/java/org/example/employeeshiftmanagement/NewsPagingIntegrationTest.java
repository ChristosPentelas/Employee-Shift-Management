package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.NewsItemRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * News paging against the real MySQL schema. The unit test proves which Sort
 * the service asks for; only a real query proves that "createdAt" and "id"
 * are valid sort properties and that pages split the rows cleanly.
 *
 * <p>Same configuration as EmployeeShiftManagementApplicationTests, so Spring
 * reuses that context and its container. {@code @Transactional} rolls every
 * insert back after each test, so the shared database is left as it was.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
class NewsPagingIntegrationTest {

    @Autowired
    private NewsItemService newsItemService;

    @Autowired
    private NewsItemRepository newsItemRepository;

    @Autowired
    private UserRepository userRepository;

    @Test
    void pagesSplitThePostsNewestFirstWithNoRepeats() {
        User author = new User();
        author.setName("Paging author");
        author.setEmail("paging-author@example.com");
        author.setPassword("not-a-real-hash");
        author.setRole("SUPERVISOR");
        author = userRepository.save(author);

        // Saved in one go, so createdAt can be equal to the microsecond; the
        // id tie-breaker is what keeps the order stable then.
        List<Integer> ids = List.of(post(author, "first"), post(author, "second"), post(author, "third"));

        Page<NewsItem> first = newsItemService.getNewsItemsByAuthor(author.getId(), PageRequest.of(0, 2));
        Page<NewsItem> second = newsItemService.getNewsItemsByAuthor(author.getId(), PageRequest.of(1, 2));

        assertEquals(3, first.getTotalElements());
        assertEquals(2, first.getTotalPages());
        assertEquals(List.of(ids.get(2), ids.get(1)), idsOf(first));
        assertEquals(List.of(ids.get(0)), idsOf(second));
    }

    private Integer post(User author, String title) {
        NewsItem item = new NewsItem();
        item.setTitle(title);
        item.setDescription("paging test");
        item.setType(NewsType.ANNOUNCEMENT);
        item.setAuthor(author);
        return newsItemRepository.saveAndFlush(item).getId();
    }

    private static List<Integer> idsOf(Page<NewsItem> page) {
        return page.getContent().stream().map(NewsItem::getId).toList();
    }
}
