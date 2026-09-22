package org.example.employeeshiftmanagement;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import org.example.employeeshiftmanagement.dto.MessageResponse;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.MessageService;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * How many SQL statements a list endpoint costs (F10).
 *
 * <p>Each test loads one page and builds the response DTOs from it, the same
 * work a controller does, then counts the statements Hibernate sent. The
 * users on each row must arrive in the same query as the rows: one statement
 * per page, however many different users the page mentions. An N+1 problem
 * shows up here as one extra statement per user.
 *
 * <p>The page holds fewer rows than its size, so Spring Data skips the
 * {@code count(*)} query - it already knows the total. That is why the
 * expected count is 1, not 2.
 *
 * <p>Same configuration as the other integration tests, so Spring reuses their
 * context and container. Statistics are switched on for this test only and
 * off again afterwards, because the SessionFactory is shared.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
class QueryCountIntegrationTest {

    @Autowired
    private MessageService messageService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EntityManager entityManager;

    @Autowired
    private EntityManagerFactory entityManagerFactory;

    private Statistics statistics;

    @BeforeEach
    void enableStatistics() {
        statistics = entityManagerFactory.unwrap(SessionFactory.class).getStatistics();
        statistics.setStatisticsEnabled(true);
    }

    @AfterEach
    void disableStatistics() {
        statistics.setStatisticsEnabled(false);
    }

    @Test
    void inboxLoadsTheSendersWithTheMessagesInOneStatement() {
        User receiver = user("receiver");
        send(user("sender-a"), receiver);
        send(user("sender-b"), receiver);
        send(user("sender-c"), receiver);

        long statements = countStatements(() ->
                messageService.getInbox(receiver.getId(), PageRequest.of(0, 20)).map(MessageResponse::from));

        assertEquals(1, statements);
    }

    @Test
    void sentMessagesLoadTheReceiversWithTheMessagesInOneStatement() {
        User sender = user("sender");
        send(sender, user("receiver-a"));
        send(sender, user("receiver-b"));
        send(sender, user("receiver-c"));

        long statements = countStatements(() ->
                messageService.getSendMessages(sender.getId(), PageRequest.of(0, 20)).map(MessageResponse::from));

        assertEquals(1, statements);
    }

    @Test
    void unreadMessagesLoadTheSendersWithTheMessagesInOneStatement() {
        User receiver = user("receiver");
        send(user("sender-a"), receiver);
        send(user("sender-b"), receiver);

        long statements = countStatements(() ->
                messageService.getUnreadMessages(receiver.getId(), PageRequest.of(0, 20)).map(MessageResponse::from));

        assertEquals(1, statements);
    }

    @Test
    void chatLoadsBothUsersWithTheMessagesInOneStatement() {
        User alice = user("alice");
        User bob = user("bob");
        send(alice, bob);
        send(bob, alice);

        long statements = countStatements(() ->
                messageService.getChatHistory(alice.getId(), bob.getId(), PageRequest.of(0, 20)).map(MessageResponse::from));

        assertEquals(1, statements);
    }

    /**
     * Writes everything to the database and empties Hibernate's first-level
     * cache before measuring. Without the clear(), the users saved above are
     * still in memory, Hibernate never needs to query for them, and the test
     * passes even when the N+1 is there.
     */
    private long countStatements(Runnable work) {
        entityManager.flush();
        entityManager.clear();
        statistics.clear();

        work.run();

        return statistics.getPrepareStatementCount();
    }

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@query-count.example.com");
        user.setPassword("not-a-real-hash");
        user.setRole("EMPLOYEE");
        return userRepository.save(user);
    }

    private void send(User sender, User receiver) {
        messageService.sendMessage(sender.getId(), receiver.getId(), "hello from " + sender.getName());
    }
}
