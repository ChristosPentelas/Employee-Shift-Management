package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

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

    public LeaveRequest updateLeaveRequest(Integer requestId, LeaveStatus newStatus) {
        LeaveRequest request = leaveRequestRepository.findById(requestId)
                .orElseThrow(() -> new ResourceNotFoundException("Leave Request Not Found with Id: " + requestId));
        request.setStatus(newStatus);
        return leaveRequestRepository.save(request);
    }
}
