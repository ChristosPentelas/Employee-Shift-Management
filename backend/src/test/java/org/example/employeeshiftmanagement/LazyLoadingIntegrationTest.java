package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.dto.LeaveRequestResponse;
import org.example.employeeshiftmanagement.dto.MessageResponse;
import org.example.employeeshiftmanagement.dto.NewsItemResponse;
import org.example.employeeshiftmanagement.dto.ShiftResponse;
import org.example.employeeshiftmanagement.model.LeaveDecision;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.NewsItemRepository;
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
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Import;
import org.springframework.orm.jpa.support.OpenEntityManagerInViewInterceptor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * What a service returns must already hold every user its response shows
 * (B28).
 *
 * <p>Open Session In View is off, so the Hibernate session closes when the
 * service's transaction ends - before the controller builds the response. A
 * LAZY user the query did not load is then a {@code LazyInitializationException}
 * (a 500), not a quiet extra query. Each test does what the controller does:
 * calls the service, then builds the DTO outside any transaction.
 *
 * <p>Only the single-item loads are here; the lists are in
 * QueryCountIntegrationTest. The creates are not: they set a user they loaded
 * themselves, so there is nothing lazy to forget.
 *
 * <p>Deliberately NOT {@code @Transactional}, like ChatReadIntegrationTest: a
 * test transaction would keep the session open around the DTO, which is
 * exactly what OSIV did, and every test would pass. So nothing is rolled back;
 * the users are deleted afterwards (their shifts, leave and messages go with
 * them, ON DELETE CASCADE, V5) and the news posts by hand, since those are
 * kept without an author (SET NULL).
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class LazyLoadingIntegrationTest {

    @Autowired private MessageService messageService;
    @Autowired private NewsItemService newsItemService;
    @Autowired private LeaveRequestService leaveRequestService;
    @Autowired private ShiftService shiftService;
    @Autowired private UserService userService;

    @Autowired private UserRepository userRepository;
    @Autowired private NewsItemRepository newsItemRepository;

    @Autowired private ApplicationContext context;

    private final List<String> emails = new ArrayList<>();
    private final List<Integer> newsIds = new ArrayList<>();

    @AfterEach
    void deleteWhatTheTestCreated() {
        newsIds.forEach(newsItemRepository::deleteById);
        for (String email : emails) {
            userRepository.findByEmail(email).ifPresent(user -> userService.deleteUser(user.getId()));
        }
    }

    /**
     * Spring Boot registers this interceptor only while
     * spring.jpa.open-in-view is true. If it comes back, the tests below pass
     * whatever the queries load, as they would in the app.
     */
    @Test
    void openSessionInViewIsOff() {
        assertEquals(0, context.getBeanNamesForType(OpenEntityManagerInViewInterceptor.class).length);
    }

    @Test
    void markingAMessageReadReturnsItsSenderAndReceiver() {
        User sender = user("sender");
        User receiver = user("receiver");
        Message message = messageService.sendMessage(sender.getId(), receiver.getId(), "Hello");

        MessageResponse response = MessageResponse.from(messageService.markAsRead(message.getId(), receiver.getId()));

        assertEquals("sender", response.sender().name());
        assertEquals("receiver", response.receiver().name());
    }

    @Test
    void aNewsItemByIdReturnsItsAuthor() {
        NewsItem item = post(user("author"));

        NewsItemResponse response = NewsItemResponse.from(newsItemService.getNewsItemById(item.getId()));

        assertEquals("author", response.author().name());
    }

    @Test
    void updatingANewsItemReturnsItsAuthor() {
        NewsItem item = post(user("author"));
        NewsItem details = new NewsItem();
        details.setTitle("Edited");
        details.setDescription("Edited");

        NewsItemResponse response = NewsItemResponse.from(newsItemService.updateNewsItem(details, item.getId()));

        assertEquals("author", response.author().name());
    }

    @Test
    void decidingALeaveRequestReturnsTheEmployee() {
        User employee = user("employee");
        LeaveRequest request = new LeaveRequest();
        request.setStartDate(LocalDate.of(2030, 2, 1));
        request.setEndDate(LocalDate.of(2030, 2, 3));
        request.setReason("Holiday");
        LeaveRequest saved = leaveRequestService.createLeaveRequest(employee.getId(), request);

        LeaveRequestResponse response = LeaveRequestResponse.from(
                leaveRequestService.updateLeaveRequest(saved.getId(), LeaveDecision.APPROVED).request());

        assertEquals("employee", response.user().name());
    }

    @Test
    void updatingAShiftReturnsTheEmployee() {
        User employee = user("employee");
        Shift saved = shiftService.createShift(employee.getId(), shift(LocalTime.of(9, 0), LocalTime.of(17, 0)));

        ShiftResponse response = ShiftResponse.from(
                shiftService.updateShift(saved.getId(), shift(LocalTime.of(10, 0), LocalTime.of(18, 0))));

        assertEquals("employee", response.user().name());
    }

    // --- Test data ---

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@lazy-loading-test.example");
        user.setPassword("secret123");
        user.setRole("EMPLOYEE");
        emails.add(user.getEmail());
        return userRepository.save(user);
    }

    private NewsItem post(User author) {
        NewsItem item = new NewsItem();
        item.setTitle("Title");
        item.setDescription("Lazy loading test");
        item.setType(NewsType.ANNOUNCEMENT);
        NewsItem saved = newsItemService.createNewsItem(item, author.getId());
        newsIds.add(saved.getId());
        return saved;
    }

    private static Shift shift(LocalTime start, LocalTime end) {
        Shift shift = new Shift();
        shift.setDate(LocalDate.of(2030, 1, 7));
        shift.setStartTime(start);
        shift.setEndTime(end);
        shift.setPosition("Cashier");
        return shift;
    }
}
