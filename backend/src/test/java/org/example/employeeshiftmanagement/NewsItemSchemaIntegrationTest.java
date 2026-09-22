package org.example.employeeshiftmanagement;

import jakarta.persistence.EntityManager;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.repository.NewsItemRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * The rules on news_items.created_at (B25), checked against the real schema.
 *
 * <p>Hibernate's ddl-auto=validate checks that columns exist with the right
 * type, but not whether they are nullable - so an entity saying
 * {@code nullable = false} proves nothing about the database. Only a write
 * that reaches MySQL does.
 *
 * <p>Same configuration as the other integration tests, so Spring reuses their
 * context and container; {@code @Transactional} rolls every insert back.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
class NewsItemSchemaIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private NewsItemRepository newsItemRepository;

    @Autowired
    private EntityManager entityManager;

    /**
     * Plain SQL on purpose: every save through JPA passes @PrePersist, which
     * sets createdAt, so a JPA save would pass whether the column allows NULL
     * or not. The constraint exists for the writes that skip JPA.
     *
     * <p>An explicit NULL, not a left-out column: MySQL reports a missing
     * column with no default as a generic error (1364, SQL state HY000) that
     * Spring cannot classify, while NULL into a NOT NULL column is a
     * constraint violation (1048, SQL state 23000) - exactly the rule tested.
     */
    @Test
    void theDatabaseRejectsANewsItemWithoutACreationTime() {
        assertThrows(DataIntegrityViolationException.class, () -> jdbcTemplate.update(
                "INSERT INTO news_items (title, description, type, created_at) "
                        + "VALUES ('No time', 'Inserted by hand', 'ANNOUNCEMENT', NULL)"));
    }

    @Test
    void anUpdateCannotChangeTheCreationTime() {
        NewsItem item = new NewsItem();
        item.setTitle("Original");
        item.setDescription("Posted once");
        item.setType(NewsType.ANNOUNCEMENT);
        Integer id = newsItemRepository.saveAndFlush(item).getId();

        // Both values are read back from the database, never taken from Java:
        // the column keeps microseconds and MySQL rounds, so the LocalDateTime
        // in memory (nanoseconds) may not equal what was stored.
        NewsItem stored = reload(id);
        LocalDateTime created = stored.getCreatedAt();

        stored.setTitle("Edited");
        stored.setCreatedAt(LocalDateTime.of(1999, 1, 1, 0, 0));
        newsItemRepository.saveAndFlush(stored);

        NewsItem reloaded = reload(id);
        assertEquals("Edited", reloaded.getTitle());
        assertEquals(created, reloaded.getCreatedAt());
    }

    /** Reads the row from the database, not from Hibernate's first-level cache. */
    private NewsItem reload(Integer id) {
        entityManager.clear();
        return newsItemRepository.findById(id).orElseThrow();
    }
}
