package org.example.employeeshiftmanagement;

import jakarta.persistence.EntityManager;
import org.example.employeeshiftmanagement.model.LeaveDecision;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.LeaveDecisionResult;
import org.example.employeeshiftmanagement.service.LeaveRequestService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Approving leave removes the employee's shifts on the leave days (B31 step
 * 31c, decided 2026-10-25), by the same date rule as ShiftLeaveIntegrationTest:
 * a shift belongs to the date it is filed under.
 *
 * <p>Against MySQL, not a mock: which shifts go is decided by the DELETE in
 * ShiftRepository. That the employee's lock holds back a shift saved at the
 * same moment is ShiftConcurrencyIntegrationTest's job.
 *
 * <p>{@code @Transactional} rolls every row back. The bulk DELETE skips
 * Hibernate's first-level cache, so the shifts are read back with a query
 * after clearing it, never with findById, which could answer from the cache.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
class LeaveApprovalIntegrationTest {

    // Leave from Monday 2 to Wednesday 4 November.
    private static final LocalDate FIRST_DAY = LocalDate.of(2026, 11, 2);
    private static final LocalDate LAST_DAY = LocalDate.of(2026, 11, 4);

    @Autowired private LeaveRequestService leaveRequestService;
    @Autowired private UserRepository userRepository;
    @Autowired private LeaveRequestRepository leaveRequestRepository;
    @Autowired private ShiftRepository shiftRepository;
    @Autowired private EntityManager entityManager;

    private User employee;
    private User colleague;
    private Integer leaveId;

    @BeforeEach
    void anEmployeeWithShiftsAroundTheirLeave() {
        employee = user("on-leave");
        colleague = user("colleague");
        leaveId = pendingLeave(employee);

        shift(employee, FIRST_DAY.minusDays(1), "09:00", "17:00");  // Sunday: stays
        shift(employee, FIRST_DAY.minusDays(1), "22:00", "06:00");  // Sunday night into Monday: stays
        shift(employee, FIRST_DAY, "09:00", "17:00");               // goes
        shift(employee, FIRST_DAY.plusDays(1), "09:00", "13:00");   // goes
        shift(employee, FIRST_DAY.plusDays(1), "14:00", "18:00");   // goes
        shift(employee, LAST_DAY, "22:00", "06:00");                // Wednesday night: goes
        shift(employee, LAST_DAY.plusDays(1), "09:00", "17:00");    // Thursday: stays
        shift(colleague, FIRST_DAY, "09:00", "17:00");              // not theirs: stays
    }

    @Test
    void approvingRemovesTheShiftsOnTheLeaveDaysAndSaysHowMany() {
        LeaveDecisionResult result = leaveRequestService.updateLeaveRequest(leaveId, LeaveDecision.APPROVED);

        assertEquals(LeaveStatus.APPROVED, result.request().getStatus());
        assertEquals(4, result.removedShifts());
        assertEquals(List.of("2026-11-01 09:00", "2026-11-01 22:00", "2026-11-05 09:00"), shiftsOf(employee));
        assertEquals(List.of("2026-11-02 09:00"), shiftsOf(colleague));
    }

    @Test
    void rejectingRemovesNothing() {
        LeaveDecisionResult result = leaveRequestService.updateLeaveRequest(leaveId, LeaveDecision.REJECTED);

        assertEquals(0, result.removedShifts());
        assertEquals(7, shiftsOf(employee).size());
    }

    @Test
    void approvingLeaveWithNoShiftsRemovesNone() {
        LeaveDecisionResult result =
                leaveRequestService.updateLeaveRequest(pendingLeave(colleague, LAST_DAY), LeaveDecision.APPROVED);

        assertEquals(0, result.removedShifts());
        assertEquals(1, shiftsOf(colleague).size());
    }

    /** The user's shifts, as "yyyy-MM-dd HH:mm", read from the database. */
    private List<String> shiftsOf(User user) {
        entityManager.flush();
        entityManager.clear();
        return shiftRepository.findByUserIdAndDateBetween(user.getId(), FIRST_DAY.minusDays(7), LAST_DAY.plusDays(7),
                        Sort.by("date", "startTime"))
                .stream()
                .map(shift -> shift.getDate() + " " + shift.getStartTime())
                .toList();
    }

    // --- Test data, saved straight through the repositories ---

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@leave-approval-test.example");
        user.setPassword("not-a-real-hash");
        user.setRole("EMPLOYEE");
        return userRepository.save(user);
    }

    private Integer pendingLeave(User user) {
        return pendingLeave(user, FIRST_DAY);
    }

    /** Leave from start to LAST_DAY. */
    private Integer pendingLeave(User user, LocalDate start) {
        LeaveRequest leave = new LeaveRequest();
        leave.setUser(user);
        leave.setStartDate(start);
        leave.setEndDate(LAST_DAY);
        leave.setReason("Holiday");
        leave.setStatus(LeaveStatus.PENDING);
        return leaveRequestRepository.save(leave).getId();
    }

    private void shift(User user, LocalDate date, String start, String end) {
        Shift shift = new Shift();
        shift.setUser(user);
        shift.setDate(date);
        shift.setStartTime(LocalTime.parse(start));
        shift.setEndTime(LocalTime.parse(end));
        shift.setPosition("Ταμείο");
        shiftRepository.save(shift);
    }
}
