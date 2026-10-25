package org.example.employeeshiftmanagement;

import jakarta.persistence.EntityManager;
import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * The rules on messages.timestamp (B29): it is the time the message was saved,
 * and no later save changes it. The same rules as news_items.created_at (B25).
 *
 * <p>Against MySQL, not a mock: {@code updatable = false} only changes the SQL
 * Hibernate writes, so only an UPDATE that reaches the database shows it.
 *
 * <p>Same configuration as the other integration tests, so Spring reuses their
 * context and container; {@code @Transactional} rolls every insert back.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
class MessageTimestampIntegrationTest {

    private static final LocalDateTime LONG_AGO = LocalDateTime.of(1999, 1, 1, 0, 0);

    @Autowired private MessageRepository messageRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private EntityManager entityManager;

    @Test
    void savingAMessageStampsTheTimeOfTheSave() {
        // Whole seconds on both sides: the column keeps microseconds and MySQL
        // rounds, so the stored time can be a hair off the one Java took.
        LocalDateTime before = LocalDateTime.now().truncatedTo(ChronoUnit.SECONDS);
        Message message = message();
        message.setTimestamp(LONG_AGO);
        Integer id = messageRepository.saveAndFlush(message).getId();
        LocalDateTime after = LocalDateTime.now().plusSeconds(1);

        LocalDateTime stored = reload(id).getTimestamp();
        assertFalse(stored.isBefore(before), "stored " + stored + ", saved after " + before);
        assertFalse(stored.isAfter(after), "stored " + stored + ", saved before " + after);
    }

    @Test
    void anUpdateCannotChangeTheTimestamp() {
        Integer id = messageRepository.saveAndFlush(message()).getId();

        // Read back from the database, never taken from Java (see above).
        Message stored = reload(id);
        LocalDateTime sent = stored.getTimestamp();

        // markAsRead's save, plus a timestamp that must not reach the row.
        stored.setRead(true);
        stored.setTimestamp(LONG_AGO);
        messageRepository.saveAndFlush(stored);

        Message reloaded = reload(id);
        assertTrue(reloaded.isRead());
        assertEquals(sent, reloaded.getTimestamp());
    }

    private Message message() {
        Message message = new Message();
        message.setSender(user("sender"));
        message.setReceiver(user("receiver"));
        message.setContent("Hello");
        return message;
    }

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@message-timestamp-test.example");
        user.setPassword("not-a-real-hash");
        user.setRole("EMPLOYEE");
        return userRepository.save(user);
    }

    /** Reads the row from the database, not from Hibernate's first-level cache. */
    private Message reload(Integer id) {
        entityManager.clear();
        return messageRepository.findById(id).orElseThrow();
    }
}
