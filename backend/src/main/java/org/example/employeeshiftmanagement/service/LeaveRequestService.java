package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class LeaveRequestService {

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

    public List<LeaveRequest> getAllLeaveRequests() {
        return leaveRequestRepository.findAll();
    }

    public List<LeaveRequest> getLeavesByUser(Integer userId) {
        return leaveRequestRepository.findByUserId(userId);
    }

    public List<LeaveRequest> getLeavesByStatus(LeaveStatus status) {
        return leaveRequestRepository.findByStatus(status);
    }

    public List<LeaveRequest> getLeavesByUserAndStatus(Integer userId, LeaveStatus status) {
        userService.findUserById(userId);
        return leaveRequestRepository.findByUserIdAndStatus(userId, status);
    }

    public LeaveRequest updateLeaveRequest(Integer requestId, LeaveStatus newStatus) {
        LeaveRequest request = leaveRequestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Leave Request Not Found with Id: " + requestId));
        request.setStatus(newStatus);
        return leaveRequestRepository.save(request);
    }
}
