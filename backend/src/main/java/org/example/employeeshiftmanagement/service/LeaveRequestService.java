package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.LeaveDecision;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LeaveRequestService {

    /** Latest leave first, by the day it starts. There is no "submitted at" column to sort on. */
    private static final Sort LATEST_FIRST =
            Sort.by(Sort.Order.desc("startDate"), Sort.Order.desc("id"));

    private final LeaveRequestRepository leaveRequestRepository;
    private final UserService userService;
    private final ShiftService shiftService;

    public LeaveRequestService(LeaveRequestRepository leaveRequestRepository, UserService userService,
                               ShiftService shiftService) {
        this.leaveRequestRepository = leaveRequestRepository;
        this.userService = userService;
        this.shiftService = shiftService;
    }

    @Transactional
    public LeaveRequest createLeaveRequest(Integer userId, LeaveRequest request) {
        // Resolve the employee here rather than trusting one supplied by the
        // caller, the same way ShiftService and MessageService already do.
        // An unknown id now fails instead of being saved as a foreign key.
        User user = userService.findUserById(userId);
        request.setUser(user);

        request.setStatus(LeaveStatus.PENDING);
        return leaveRequestRepository.save(request);
    }

    public Page<LeaveRequest> getAllLeaveRequests(Pageable pageable) {
        return leaveRequestRepository.findAll(Paging.withSort(pageable, LATEST_FIRST));
    }

    public Page<LeaveRequest> getLeavesByUser(Integer userId, Pageable pageable) {
        return leaveRequestRepository.findByUserId(userId, Paging.withSort(pageable, LATEST_FIRST));
    }

    public Page<LeaveRequest> getLeavesByStatus(LeaveStatus status, Pageable pageable) {
        return leaveRequestRepository.findByStatus(status, Paging.withSort(pageable, LATEST_FIRST));
    }

    public Page<LeaveRequest> getLeavesByUserAndStatus(Integer userId, LeaveStatus status, Pageable pageable) {
        userService.findUserById(userId);
        return leaveRequestRepository.findByUserIdAndStatus(userId, status, Paging.withSort(pageable, LATEST_FIRST));
    }

    /**
     * A request is answered once (B63): approving a rejected one, or answering
     * it a second time, is a ConflictException (409). Before, any status could
     * be set at any time; only the app's hidden buttons stood in the way.
     *
     * The row is locked first, so two supervisors answering at the same moment
     * cannot both see PENDING. The lock is the transaction's first statement,
     * and a locking read always sees the latest committed row, so MySQL's
     * REPEATABLE READ needs no change here (compare ShiftService).
     *
     * Approving removes the employee's shifts on the leave days (B31, decided
     * 2026-10-25), under the employee's lock - the one createShift and
     * updateShift take. A shift being saved at that moment is waited for and
     * then removed too; one saved just after waits until this commits, and its
     * leave check then sees APPROVED. Without the lock the second case slips
     * through: its check would still read PENDING.
     *
     * The lock order is always the leave row, then the employee. ShiftService
     * takes only the employee and reads leave without locking it, so neither
     * side can hold what the other is waiting for (no deadlock).
     *
     * REPEATABLE READ is still enough: a DELETE, like a locking read, works on
     * the latest committed rows, not on this transaction's snapshot.
     */
    @Transactional
    public LeaveDecisionResult updateLeaveRequest(Integer requestId, LeaveDecision decision) {
        LeaveRequest request = leaveRequestRepository.findLockedById(requestId)
                .orElseThrow(() -> new ResourceNotFoundException("Leave request", requestId));
        if (request.getStatus() != LeaveStatus.PENDING) {
            throw new ConflictException(
                    "Leave request " + requestId + " is already " + request.getStatus());
        }
        request.setStatus(decision.toStatus());
        LeaveRequest answered = leaveRequestRepository.save(request);

        int removedShifts = 0;
        if (decision == LeaveDecision.APPROVED) {
            Integer userId = request.getUser().getId();
            userService.findLockedUserById(userId);
            removedShifts = shiftService.removeShiftsDuring(userId, request.getStartDate(), request.getEndDate());
        }
        return new LeaveDecisionResult(answered, removedShifts);
    }
}
