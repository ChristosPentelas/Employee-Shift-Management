package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.example.employeeshiftmanagement.repository.NewsItemRepository;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * What deleting a user does to the rows that point at them (F12, B7).
 *
 * <p>The rule lives in the schema: every foreign key to users has an
 * ON DELETE action, so deleting the user is one statement and MySQL removes or
 * detaches the rest. {@link #everyForeignKeyToUsersSaysWhatHappensOnDelete}
 * guards it for the next table that references users.
 *
 * <p>Deliberately NOT {@code @Transactional}, unlike most integration tests.
 * A test transaction is rolled back, so Hibernate never sends the DELETE to
 * MySQL, the foreign keys are never checked, and a delete the database would
 * refuse still passes. That is how B7 went unnoticed.
 *
 * <p>The price: nothing is rolled back for us, and the other tests count on an
 * empty database (QueryCountIntegrationTest counts "everyone's" lists). So
 * every user and news post is created through the helpers below, which
 * remember them, and {@link #deleteWhatTheTestCreated} removes them.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class UserDeletionIntegrationTest {

    private static final LocalDate DAY = LocalDate.of(2026, 10, 5);

    @Autowired private UserService userService;

    @Autowired private UserRepository userRepository;
    @Autowired private ShiftRepository shiftRepository;
    @Autowired private LeaveRequestRepository leaveRequestRepository;
    @Autowired private MessageRepository messageRepository;
    @Autowired private NewsItemRepository newsItemRepository;

    @Autowired private JdbcTemplate jdbcTemplate;

    private final List<String> emails = new ArrayList<>();
    private final List<Integer> newsIds = new ArrayList<>();

    /**
     * News first: a kept post outlives its author, so deleting the users would
     * not remove it. Then each user still present - the colleague, or the
     * deleted user too if the test failed before deleting them.
     */
    @AfterEach
    void deleteWhatTheTestCreated() {
        newsItemRepository.deleteAllById(newsIds);
        for (String email : emails) {
            userRepository.findByEmail(email).ifPresent(user -> userService.deleteUser(user.getId()));
        }
    }

    @Test
    void deletingAUserDeletesTheirShiftsLeaveRequestsAndMessages() {
        User employee = user("leaving");
        User colleague = user("staying");
        Shift shift = shift(employee);
        LeaveRequest leave = leave(employee);
        Message sent = message(employee, colleague);
        Message received = message(colleague, employee);
        Shift colleaguesShift = shift(colleague);

        userService.deleteUser(employee.getId());

        assertFalse(userRepository.existsById(employee.getId()), "the user");
        assertFalse(shiftRepository.existsById(shift.getId()), "their shift");
        assertFalse(leaveRequestRepository.existsById(leave.getId()), "their leave request");
        assertFalse(messageRepository.existsById(sent.getId()), "a message they sent");
        assertFalse(messageRepository.existsById(received.getId()), "a message they received");
        assertTrue(userRepository.existsById(colleague.getId()), "the colleague is untouched");
        assertTrue(shiftRepository.existsById(colleaguesShift.getId()), "the colleague's shift is untouched");
    }

    /**
     * B7: this used to fail on news_items' foreign key. Decided 2026-10-04: the
     * post stays, with no author; the app shows it as "Από: Άγνωστος" (F29).
     *
     * <p>Read with plain SQL so the answer comes from the database, not from an
     * entity Hibernate may still remember.
     */
    @Test
    void deletingAnAuthorKeepsTheirNewsWithNoAuthor() {
        User author = user("author");
        NewsItem news = news(author);

        userService.deleteUser(author.getId());

        assertFalse(userRepository.existsById(author.getId()), "the author");
        List<Integer> authorIds = jdbcTemplate.queryForList(
                "SELECT author_id FROM news_items WHERE id = ?", Integer.class, news.getId());
        assertEquals(1, authorIds.size(), "the post is kept");
        assertNull(authorIds.get(0), "the post has no author");
    }

    /**
     * Every foreign key to users, with what MySQL does to its rows when the
     * user is deleted. A new table that references users makes this fail
     * until someone decides its rule and adds it here - which is the point: a
     * key without a rule refuses the delete, and only at runtime.
     *
     * <p>A key declared without ON DELETE is listed with rule NO ACTION, which
     * InnoDB treats like RESTRICT.
     */
    @Test
    void everyForeignKeyToUsersSaysWhatHappensOnDelete() {
        Map<String, String> rules = new TreeMap<>();
        jdbcTemplate.query("""
                SELECT k.TABLE_NAME, k.COLUMN_NAME, r.DELETE_RULE
                FROM information_schema.REFERENTIAL_CONSTRAINTS r
                JOIN information_schema.KEY_COLUMN_USAGE k
                  ON k.CONSTRAINT_SCHEMA = r.CONSTRAINT_SCHEMA
                 AND k.CONSTRAINT_NAME = r.CONSTRAINT_NAME
                 AND k.TABLE_NAME = r.TABLE_NAME
                WHERE r.CONSTRAINT_SCHEMA = DATABASE()
                  AND r.REFERENCED_TABLE_NAME = 'users'
                """, row -> {
            rules.put(row.getString("TABLE_NAME") + "." + row.getString("COLUMN_NAME"),
                    row.getString("DELETE_RULE"));
        });

        assertEquals(new TreeMap<>(Map.of(
                "leaves_requests.user_id", "CASCADE",
                "messages.receiver_id", "CASCADE",
                "messages.sender_id", "CASCADE",
                "news_items.author_id", "SET NULL",
                "shifts.user_id", "CASCADE")), rules);
    }

    // --- Test data, saved straight through the repositories ---

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@delete-test.example");
        user.setPassword("secret123");
        user.setRole("EMPLOYEE");
        emails.add(user.getEmail());
        return userRepository.save(user);
    }

    private Shift shift(User employee) {
        Shift shift = new Shift();
        shift.setDate(DAY);
        shift.setStartTime(LocalTime.of(9, 0));
        shift.setEndTime(LocalTime.of(17, 0));
        shift.setPosition("Cashier");
        shift.setUser(employee);
        return shiftRepository.save(shift);
    }

    private LeaveRequest leave(User employee) {
        LeaveRequest leave = new LeaveRequest();
        leave.setStartDate(DAY);
        leave.setEndDate(DAY.plusDays(2));
        leave.setReason("Holiday");
        leave.setUser(employee);
        return leaveRequestRepository.save(leave);
    }

    private Message message(User sender, User receiver) {
        Message message = new Message();
        message.setSender(sender);
        message.setReceiver(receiver);
        message.setContent("Hello");
        return messageRepository.save(message);
    }

    private NewsItem news(User author) {
        NewsItem news = new NewsItem();
        news.setTitle("Meeting");
        news.setDescription("Friday at 10");
        news.setType(NewsType.ANNOUNCEMENT);
        news.setAuthor(author);
        news = newsItemRepository.save(news);
        newsIds.add(news.getId());
        return news;
    }
}
