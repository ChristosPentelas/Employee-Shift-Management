package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.MessageService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Marking a whole chat read with one UPDATE (F28, B27).
 *
 * <p>The controller and service tests mock the repository, so they cannot see
 * the JPQL. This one runs it against MySQL: it proves the query parses, and
 * that it touches only the messages the other person sent to the caller.
 *
 * <p>Deliberately NOT {@code @Transactional}, like UserDeletionIntegrationTest.
 * A test transaction would be joined by MessageService, so a service method
 * that forgot its own {@code @Transactional} would still pass here - and then
 * fail in the app, because a modifying query refuses to run outside a
 * transaction. Without one, every test below fails until the service has it.
 *
 * <p>The price: nothing is rolled back, so the users are deleted afterwards,
 * which deletes their messages too (ON DELETE CASCADE, V5).
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class ChatReadIntegrationTest {

    @Autowired private MessageService messageService;
    @Autowired private UserService userService;

    @Autowired private UserRepository userRepository;
    @Autowired private MessageRepository messageRepository;

    @Autowired private JdbcTemplate jdbcTemplate;

    private final List<String> emails = new ArrayList<>();

    @AfterEach
    void deleteWhatTheTestCreated() {
        for (String email : emails) {
            userRepository.findByEmail(email).ifPresent(user -> userService.deleteUser(user.getId()));
        }
    }

    @Test
    void onlyWhatTheOtherPersonSentToTheCallerIsMarkedRead() {
        User me = user("me");
        User other = user("other");
        User third = user("third");
        Message fromOther1 = message(other, me);
        Message fromOther2 = message(other, me);
        Message mine = message(me, other);
        Message fromThird = message(third, me);
        Message otherToThird = message(other, third);

        int marked = messageService.markChatAsRead(other.getId(), me.getId());

        assertEquals(2, marked, "rows changed");
        assertTrue(isRead(fromOther1), "sent to me by the other person");
        assertTrue(isRead(fromOther2), "sent to me by the other person");
        assertFalse(isRead(mine), "mine: only the other person can read it");
        assertFalse(isRead(fromThird), "from someone else: a different chat");
        assertFalse(isRead(otherToThird), "between two other people");
    }

    @Test
    void markingAChatReadTwiceChangesNothingTheSecondTime() {
        User me = user("me");
        User other = user("other");
        Message fromOther = message(other, me);

        messageService.markChatAsRead(other.getId(), me.getId());
        int markedAgain = messageService.markChatAsRead(other.getId(), me.getId());

        // The count is "newly read", so the WHERE skips rows already read.
        assertEquals(0, markedAgain);
        assertTrue(isRead(fromOther));
    }

    @Test
    void markingAChatWithNobodyReadChangesNothing() {
        User me = user("me");
        User other = user("other");
        Message fromOther = message(other, me);

        // Not an error: there is simply nothing from that id to mark.
        int marked = messageService.markChatAsRead(-1, me.getId());

        assertEquals(0, marked);
        assertFalse(isRead(fromOther));
    }

    /**
     * Read with plain SQL so the answer comes from the database, not from an
     * entity Hibernate may still remember: a bulk UPDATE skips Hibernate's
     * memory of the rows.
     */
    private boolean isRead(Message message) {
        return jdbcTemplate.queryForObject(
                "SELECT is_read FROM messages WHERE id = ?", Boolean.class, message.getId());
    }

    // --- Test data, saved straight through the repositories ---

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@chat-read-test.example");
        user.setPassword("secret123");
        user.setRole("EMPLOYEE");
        emails.add(user.getEmail());
        return userRepository.save(user);
    }

    private Message message(User sender, User receiver) {
        Message message = new Message();
        message.setSender(sender);
        message.setReceiver(receiver);
        message.setContent("Hello");
        return messageRepository.save(message);
    }
}
