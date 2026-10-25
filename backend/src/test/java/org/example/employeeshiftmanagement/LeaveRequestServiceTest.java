package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.LeaveDecision;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.example.employeeshiftmanagement.service.LeaveDecisionResult;
import org.example.employeeshiftmanagement.service.LeaveRequestService;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;

import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * A leave request is answered once (B63), as a plain unit test: no Spring,
 * no Docker.
 *
 * Whether the row lock really makes a second supervisor wait is not tested
 * here - a mock has no locks. The tests check that the locking lookup is the
 * one used; the same @Lock is proven to block in ShiftConcurrencyIntegrationTest.
 *
 * The same goes for approving, which removes the employee's shifts (B31):
 * these tests check that the employee is locked first and that a rejection
 * removes nothing. Which shifts go is LeaveApprovalIntegrationTest's job, and
 * that the lock really holds a shift back is ShiftConcurrencyIntegrationTest's.
 */
class LeaveRequestServiceTest {

    private final LeaveRequestRepository leaveRequestRepository = mock(LeaveRequestRepository.class);
    private final UserService userService = mock(UserService.class);
    private final ShiftService shiftService = mock(ShiftService.class);
    private final LeaveRequestService leaveRequestService =
            new LeaveRequestService(leaveRequestRepository, userService, shiftService);

    @BeforeEach
    void savingReturnsWhatWasSaved() {
        when(leaveRequestRepository.save(any(LeaveRequest.class))).thenAnswer(call -> call.getArgument(0));
    }

    /** Request 5, stored with the given status, as the locking lookup returns it. */
    private LeaveRequest stored(LeaveStatus status) {
        LeaveRequest leave = new LeaveRequest();
        leave.setId(5);
        leave.setStartDate(LocalDate.of(2026, 10, 1));
        leave.setEndDate(LocalDate.of(2026, 10, 5));
        leave.setReason("Surgery");
        leave.setStatus(status);
        leave.setUser(TestUsers.employee());
        when(leaveRequestRepository.findLockedById(5)).thenReturn(Optional.of(leave));
        return leave;
    }

    @Test
    void aPendingRequestCanBeApproved() {
        stored(LeaveStatus.PENDING);

        LeaveRequest answered = leaveRequestService.updateLeaveRequest(5, LeaveDecision.APPROVED).request();

        assertEquals(LeaveStatus.APPROVED, answered.getStatus());
        verify(leaveRequestRepository).save(answered);
    }

    @Test
    void aPendingRequestCanBeRejected() {
        stored(LeaveStatus.PENDING);

        LeaveRequest answered = leaveRequestService.updateLeaveRequest(5, LeaveDecision.REJECTED).request();

        assertEquals(LeaveStatus.REJECTED, answered.getStatus());
    }

    @Test
    void anApprovedRequestCannotBeRejectedLater() {
        LeaveRequest leave = stored(LeaveStatus.APPROVED);

        ConflictException e = assertThrows(ConflictException.class,
                () -> leaveRequestService.updateLeaveRequest(5, LeaveDecision.REJECTED));

        assertEquals("Leave request 5 is already APPROVED", e.getMessage());
        assertEquals(LeaveStatus.APPROVED, leave.getStatus());
        verify(leaveRequestRepository, never()).save(any());
    }

    @Test
    void aRejectedRequestCannotBeRejectedAgain() {
        // The same answer twice is still a second answer: the supervisor
        // who sent it second should hear that someone else got there first.
        stored(LeaveStatus.REJECTED);

        assertThrows(ConflictException.class,
                () -> leaveRequestService.updateLeaveRequest(5, LeaveDecision.REJECTED));
        verify(leaveRequestRepository, never()).save(any());
    }

    @Test
    void aMissingRequestIsNotFound() {
        when(leaveRequestRepository.findLockedById(anyInt())).thenReturn(Optional.empty());

        ResourceNotFoundException e = assertThrows(ResourceNotFoundException.class,
                () -> leaveRequestService.updateLeaveRequest(99, LeaveDecision.APPROVED));
        assertEquals("Leave request not found: 99", e.getMessage());
    }

    @Test
    void theRequestIsReadWithTheLock() {
        // findById would read it unlocked, and two answers at the same moment
        // could both see PENDING.
        stored(LeaveStatus.PENDING);

        leaveRequestService.updateLeaveRequest(5, LeaveDecision.APPROVED);

        verify(leaveRequestRepository, never()).findById(anyInt());
    }

    @Test
    void approvingRemovesTheEmployeesShiftsOnTheLeaveDays() {
        stored(LeaveStatus.PENDING);
        when(shiftService.removeShiftsDuring(7, LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 5)))
                .thenReturn(2);

        LeaveDecisionResult result = leaveRequestService.updateLeaveRequest(5, LeaveDecision.APPROVED);

        assertEquals(2, result.removedShifts());
    }

    @Test
    void approvingLocksTheEmployeeBeforeRemovingTheirShifts() {
        // The lock ShiftService takes: without it, a shift saved at the same
        // moment would not wait for the approval (B31).
        stored(LeaveStatus.PENDING);

        leaveRequestService.updateLeaveRequest(5, LeaveDecision.APPROVED);

        InOrder order = inOrder(userService, shiftService);
        order.verify(userService).findLockedUserById(7);
        order.verify(shiftService).removeShiftsDuring(anyInt(), any(), any());
    }

    @Test
    void rejectingRemovesNoShifts() {
        stored(LeaveStatus.PENDING);

        LeaveDecisionResult result = leaveRequestService.updateLeaveRequest(5, LeaveDecision.REJECTED);

        assertEquals(0, result.removedShifts());
        verify(shiftService, never()).removeShiftsDuring(anyInt(), any(), any());
    }
}
