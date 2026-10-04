package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
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
import org.example.employeeshiftmanagement.service.LeaveRequestService;
import org.example.employeeshiftmanagement.service.MessageService;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Pageable;
import org.springframework.transaction.ConfigurableTransactionManager;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionExecution;
import org.springframework.transaction.TransactionExecutionListener;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Every service method that writes runs as one transaction (F11).
 *
 * <p>A listener on the transaction manager records each transaction that
 * begins, commits or rolls back while the service method runs. A method
 * without its own boundary shows up as several small transactions, one per
 * built-in repository call (for example {@code SimpleJpaRepository.findById},
 * then {@code SimpleJpaRepository.save}). Derived queries such as
 * {@code findByUserIdAndDateBetween} do not even appear: Spring Data gives
 * them no transaction, so outside a service boundary they run in none. A
 * method with a boundary shows up as exactly one transaction, named after
 * itself; repository calls inside it join that one and start none of their
 * own.
 *
 * <p>This class is deliberately NOT {@code @Transactional}, unlike the other
 * integration tests. A test transaction would wrap every call, the service's
 * repository calls would all join it, and the test would pass with or without
 * the service's annotation - it could never fail.
 *
 * <p>The price: nothing here is rolled back for us, and the other tests count
 * on an empty database (QueryCountIntegrationTest counts "everyone's" lists).
 * So every user is created through {@link #user}, which remembers the email,
 * and {@link #deleteWhatTheTestCreated} removes those users and all their rows.
 *
 * <p>The listener is added to the shared transaction manager only for the
 * duration of one call and removed in a {@code finally}. Registering it as a
 * test bean instead would change this class's configuration, so Spring could
 * not reuse the other tests' context and would start another MySQL container.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class TransactionBoundaryIntegrationTest {

    private static final String SERVICE_PACKAGE = "org.example.employeeshiftmanagement.service.";

    private static final LocalDate DAY = LocalDate.of(2026, 10, 5);

    @Autowired private ShiftService shiftService;
    @Autowired private LeaveRequestService leaveRequestService;
    @Autowired private MessageService messageService;
    @Autowired private NewsItemService newsItemService;
    @Autowired private UserService userService;

    @Autowired private UserRepository userRepository;
    @Autowired private ShiftRepository shiftRepository;
    @Autowired private LeaveRequestRepository leaveRequestRepository;
    @Autowired private MessageRepository messageRepository;
    @Autowired private NewsItemRepository newsItemRepository;

    @Autowired private PlatformTransactionManager transactionManager;

    /** Every email a test used, so its user can be found and deleted afterwards. */
    private final List<String> emails = new ArrayList<>();

    @AfterEach
    void deleteWhatTheTestCreated() {
        for (String email : emails) {
            userRepository.findByEmail(email).ifPresent(user -> {
                // Deleting the author keeps their news posts, with no author
                // (V5), and a leftover post would show up in other tests'
                // "all news" lists. So the posts go first, by hand.
                newsItemRepository.deleteAll(
                        newsItemRepository.findByAuthorId(user.getId(), Pageable.unpaged()).getContent());
                userService.deleteUser(user.getId());
            });
        }
    }

    // --- ShiftService ---

    @Test
    void createShiftIsOneTransaction() {
        User employee = user("create-shift");

        assertOneTransaction("ShiftService.createShift",
                () -> shiftService.createShift(employee.getId(), newShift(DAY, 9, 17)));
    }

    @Test
    void updateShiftIsOneTransaction() {
        Shift shift = shift(user("update-shift"), DAY, 9, 17);

        assertOneTransaction("ShiftService.updateShift",
                () -> shiftService.updateShift(shift.getId(), newShift(DAY, 10, 18)));
    }

    @Test
    void deleteShiftIsOneTransaction() {
        Shift shift = shift(user("delete-shift"), DAY, 9, 17);

        assertOneTransaction("ShiftService.deleteShift",
                () -> shiftService.deleteShift(shift.getId()));
    }

    /**
     * A refused write rolls back the whole operation. With one transaction
     * per repository call, the overlap check's read would simply have
     * committed and the refusal would leave no trace in the transaction log.
     */
    @Test
    void refusedOverlappingShiftRollsBackItsTransaction() {
        User employee = user("overlap");
        shift(employee, DAY, 9, 17);

        List<String> log = transactionsDuring(() -> assertThrows(ConflictException.class,
                () -> shiftService.createShift(employee.getId(), newShift(DAY, 12, 20))));

        assertEquals(List.of("begin ShiftService.createShift", "rollback ShiftService.createShift"), log);
    }

    // --- LeaveRequestService ---

    @Test
    void createLeaveRequestIsOneTransaction() {
        User employee = user("create-leave");

        assertOneTransaction("LeaveRequestService.createLeaveRequest",
                () -> leaveRequestService.createLeaveRequest(employee.getId(), newLeave()));
    }

    @Test
    void updateLeaveRequestIsOneTransaction() {
        LeaveRequest leave = newLeave();
        leave.setUser(user("update-leave"));
        leaveRequestRepository.save(leave);

        assertOneTransaction("LeaveRequestService.updateLeaveRequest",
                () -> leaveRequestService.updateLeaveRequest(leave.getId(), LeaveStatus.APPROVED));
    }

    // --- MessageService ---

    @Test
    void sendMessageIsOneTransaction() {
        User sender = user("send-from");
        User receiver = user("send-to");

        assertOneTransaction("MessageService.sendMessage",
                () -> messageService.sendMessage(sender.getId(), receiver.getId(), "Hello"));
    }

    @Test
    void markAsReadIsOneTransaction() {
        User receiver = user("read-to");
        Message message = message(user("read-from"), receiver);

        assertOneTransaction("MessageService.markAsRead",
                () -> messageService.markAsRead(message.getId(), receiver.getId()));
    }

    @Test
    void deleteMessageIsOneTransaction() {
        User sender = user("delete-message-from");
        Message message = message(sender, user("delete-message-to"));

        assertOneTransaction("MessageService.deleteMessage",
                () -> messageService.deleteMessage(message.getId(), sender.getId()));
    }

    // --- NewsItemService ---

    @Test
    void createNewsItemIsOneTransaction() {
        User author = user("create-news");

        assertOneTransaction("NewsItemService.createNewsItem",
                () -> newsItemService.createNewsItem(newNews(), author.getId()));
    }

    @Test
    void updateNewsItemIsOneTransaction() {
        NewsItem news = news(user("update-news"));

        NewsItem details = newNews();
        details.setTitle("Changed");
        assertOneTransaction("NewsItemService.updateNewsItem",
                () -> newsItemService.updateNewsItem(details, news.getId()));
    }

    @Test
    void deleteNewsItemIsOneTransaction() {
        NewsItem news = news(user("delete-news"));

        assertOneTransaction("NewsItemService.deleteNewsItem",
                () -> newsItemService.deleteNewsItem(news.getId()));
    }

    // --- UserService ---

    @Test
    void registerNewEmployeeIsOneTransaction() {
        User employee = newUser("register");

        assertOneTransaction("UserService.registerNewEmployee",
                () -> userService.registerNewEmployee(employee));
    }

    /**
     * It calls registerNewEmployee from inside the same class, which bypasses
     * the proxy - so registerNewEmployee's annotation does not apply here, and
     * only this method's own annotation gives the call a boundary.
     */
    @Test
    void createFirstSupervisorIfNoneIsOneTransaction() {
        String email = remember("first-supervisor@tx-test.example");

        List<String> log = transactionsDuring(() -> assertTrue(
                userService.createFirstSupervisorIfNone("First Boss", email, "secret123"),
                "Another test left a supervisor in the database, so nothing was created"));

        assertEquals(List.of(
                "begin UserService.createFirstSupervisorIfNone",
                "commit UserService.createFirstSupervisorIfNone"), log);
    }

    @Test
    void updateUserIsOneTransaction() {
        User employee = user("update-user");

        User details = new User();
        details.setName("Renamed");
        details.setEmail(employee.getEmail());
        details.setPhoneNumber("6900000000");
        assertOneTransaction("UserService.updateUser",
                () -> userService.updateUser(employee.getId(), details));
    }

    @Test
    void deleteUserIsOneTransaction() {
        User employee = user("delete-user");
        shift(employee, DAY, 9, 17);
        message(employee, user("delete-user-contact"));

        assertOneTransaction("UserService.deleteUser",
                () -> userService.deleteUser(employee.getId()));
    }

    // --- Recording ---

    private void assertOneTransaction(String serviceMethod, Runnable call) {
        assertEquals(List.of("begin " + serviceMethod, "commit " + serviceMethod), transactionsDuring(call),
                "Each line is one transaction event; more than one 'begin' means the method has no boundary");
    }

    /**
     * Runs the call and returns what happened to transactions meanwhile, as
     * "begin X", "commit X" or "rollback X". X is the method that started the
     * transaction, with this project's service package left out for
     * readability.
     *
     * Only transactions that begin a new one are recorded: a call that joins
     * an existing transaction neither begins nor ends anything.
     */
    private List<String> transactionsDuring(Runnable call) {
        List<String> log = new ArrayList<>();
        TransactionExecutionListener recorder = new TransactionExecutionListener() {
            @Override
            public void afterBegin(TransactionExecution transaction, Throwable beginFailure) {
                log.add("begin " + name(transaction));
            }

            @Override
            public void afterCommit(TransactionExecution transaction, Throwable commitFailure) {
                if (transaction.isNewTransaction()) {
                    log.add("commit " + name(transaction));
                }
            }

            @Override
            public void afterRollback(TransactionExecution transaction, Throwable rollbackFailure) {
                if (transaction.isNewTransaction()) {
                    log.add("rollback " + name(transaction));
                }
            }
        };

        ConfigurableTransactionManager manager = (ConfigurableTransactionManager) transactionManager;
        manager.addListener(recorder);
        try {
            call.run();
        } finally {
            manager.getTransactionExecutionListeners().remove(recorder);
        }
        return log;
    }

    private static String name(TransactionExecution transaction) {
        return transaction.getTransactionName().replace(SERVICE_PACKAGE, "");
    }

    // --- Test data, saved straight through the repositories ---

    private String remember(String email) {
        emails.add(email);
        return email;
    }

    /** Not saved yet. */
    private User newUser(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(remember(name + "@tx-test.example"));
        user.setPassword("secret123");
        user.setRole("EMPLOYEE");
        return user;
    }

    private User user(String name) {
        return userRepository.save(newUser(name));
    }

    private static Shift newShift(LocalDate date, int startHour, int endHour) {
        Shift shift = new Shift();
        shift.setDate(date);
        shift.setStartTime(LocalTime.of(startHour, 0));
        shift.setEndTime(LocalTime.of(endHour, 0));
        shift.setPosition("Cashier");
        return shift;
    }

    private Shift shift(User employee, LocalDate date, int startHour, int endHour) {
        Shift shift = newShift(date, startHour, endHour);
        shift.setUser(employee);
        return shiftRepository.save(shift);
    }

    private static LeaveRequest newLeave() {
        LeaveRequest leave = new LeaveRequest();
        leave.setStartDate(DAY);
        leave.setEndDate(DAY.plusDays(2));
        leave.setReason("Holiday");
        return leave;
    }

    private Message message(User sender, User receiver) {
        Message message = new Message();
        message.setSender(sender);
        message.setReceiver(receiver);
        message.setContent("Hello");
        return messageRepository.save(message);
    }

    private static NewsItem newNews() {
        NewsItem news = new NewsItem();
        news.setTitle("Meeting");
        news.setDescription("Friday at 10");
        news.setType(NewsType.ANNOUNCEMENT);
        return news;
    }

    private NewsItem news(User author) {
        NewsItem news = newNews();
        news.setAuthor(author);
        return newsItemRepository.save(news);
    }
}
