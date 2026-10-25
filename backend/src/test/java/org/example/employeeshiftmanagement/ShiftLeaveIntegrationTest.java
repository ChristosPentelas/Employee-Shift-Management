package org.example.employeeshiftmanagement;

import jakarta.persistence.EntityManager;
import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.exception.ProblemTypes;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * No shift on a day of the employee's approved leave (B31 step 31a).
 *
 * <p>Rules decided 2026-10-25: only APPROVED leave counts, and a shift belongs
 * to the date it is filed under. A Mon 22:00-06:00 shift is a Monday shift, so
 * leave starting on Tuesday does not block it.
 *
 * <p>Against MySQL, not a mock: the rule is the query in
 * LeaveRequestRepository (status, and both ends of the date range), and a
 * mocked repository would only answer what the test told it to.
 *
 * <p>{@code @Transactional} rolls every row back. The service's own
 * READ_COMMITTED is then ignored, which is fine here: nothing runs at the same
 * time (that is ShiftConcurrencyIntegrationTest's job).
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
class ShiftLeaveIntegrationTest {

    // Approved leave from Monday 2 to Wednesday 4 November.
    private static final LocalDate FIRST_DAY = LocalDate.of(2026, 11, 2);
    private static final LocalDate LAST_DAY = LocalDate.of(2026, 11, 4);

    @Autowired private ShiftService shiftService;
    @Autowired private UserRepository userRepository;
    @Autowired private LeaveRequestRepository leaveRequestRepository;
    @Autowired private ShiftRepository shiftRepository;
    @Autowired private EntityManager entityManager;

    private User employee;

    @BeforeEach
    void anEmployeeOnApprovedLeave() {
        employee = user("on-leave");
        leave(employee, LeaveStatus.APPROVED);
    }

    @Test
    void aShiftOnTheFirstDayOfLeaveIsRefused() {
        assertRefused(() -> shiftService.createShift(employee.getId(), dayShift(FIRST_DAY)), FIRST_DAY);
    }

    @Test
    void aShiftInTheMiddleOfLeaveIsRefused() {
        LocalDate middle = FIRST_DAY.plusDays(1);
        assertRefused(() -> shiftService.createShift(employee.getId(), dayShift(middle)), middle);
    }

    @Test
    void aShiftOnTheLastDayOfLeaveIsRefused() {
        assertRefused(() -> shiftService.createShift(employee.getId(), dayShift(LAST_DAY)), LAST_DAY);
    }

    @Test
    void theDaysAroundTheLeaveAreFree() {
        shiftService.createShift(employee.getId(), dayShift(FIRST_DAY.minusDays(1)));
        shiftService.createShift(employee.getId(), dayShift(LAST_DAY.plusDays(1)));
    }

    @Test
    void aNightShiftTheEveningBeforeTheLeaveIsAllowed() {
        // Sunday 22:00 until Monday 06:00: a Sunday shift, though it ends on
        // the first day of leave.
        shiftService.createShift(employee.getId(), shift(FIRST_DAY.minusDays(1), "22:00", "06:00"));
    }

    @Test
    void leaveThatIsNotApprovedDoesNotBlockAShift() {
        User pending = user("pending");
        leave(pending, LeaveStatus.PENDING);
        User rejected = user("rejected");
        leave(rejected, LeaveStatus.REJECTED);

        shiftService.createShift(pending.getId(), dayShift(FIRST_DAY));
        shiftService.createShift(rejected.getId(), dayShift(FIRST_DAY));
    }

    @Test
    void anotherEmployeesLeaveDoesNotBlockAShift() {
        User colleague = user("colleague");

        shiftService.createShift(colleague.getId(), dayShift(FIRST_DAY));
    }

    @Test
    void movingAShiftOntoALeaveDayIsRefused() {
        LocalDate later = LAST_DAY.plusDays(2);
        Integer id = shiftService.createShift(employee.getId(), dayShift(later)).getId();

        assertRefused(() -> shiftService.updateShift(id, dayShift(FIRST_DAY)), FIRST_DAY);

        // Refused before anything changed: the row still has its old date.
        entityManager.flush();
        entityManager.clear();
        assertEquals(later, shiftRepository.findById(id).orElseThrow().getDate());
    }

    private static void assertRefused(Runnable save, LocalDate day) {
        ConflictException e = assertThrows(ConflictException.class, save::run);
        assertEquals("On approved leave on " + day, e.getMessage());
        // The app tells this 409 apart from an overlap by its type.
        assertEquals(ProblemTypes.EMPLOYEE_ON_LEAVE, e.getType());
    }

    // --- Test data, saved straight through the repositories ---

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@shift-leave-test.example");
        user.setPassword("not-a-real-hash");
        user.setRole("EMPLOYEE");
        return userRepository.save(user);
    }

    private void leave(User user, LeaveStatus status) {
        LeaveRequest leave = new LeaveRequest();
        leave.setUser(user);
        leave.setStartDate(FIRST_DAY);
        leave.setEndDate(LAST_DAY);
        leave.setReason("Holiday");
        leave.setStatus(status);
        leaveRequestRepository.save(leave);
    }

    private static Shift dayShift(LocalDate date) {
        return shift(date, "09:00", "17:00");
    }

    private static Shift shift(LocalDate date, String start, String end) {
        Shift shift = new Shift();
        shift.setDate(date);
        shift.setStartTime(LocalTime.parse(start));
        shift.setEndTime(LocalTime.parse(end));
        shift.setPosition("Ταμείο");
        return shift;
    }
}
