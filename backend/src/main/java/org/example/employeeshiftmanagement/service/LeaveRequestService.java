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

    public LeaveRequestService(LeaveRequestRepository leaveRequestRepository, UserService userService) {
        this.leaveRequestRepository = leaveRequestRepository;
        this.userService = userService;
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
     */
    @Transactional
    public LeaveRequest updateLeaveRequest(Integer requestId, LeaveDecision decision) {
        LeaveRequest request = leaveRequestRepository.findLockedById(requestId)
                .orElseThrow(() -> new ResourceNotFoundException("Leave Request Not Found with Id: " + requestId));
        if (request.getStatus() != LeaveStatus.PENDING) {
            throw new ConflictException(
                    "Leave request " + requestId + " is already " + request.getStatus());
        }
        request.setStatus(decision.toStatus());
        return leaveRequestRepository.save(request);
    }
}
