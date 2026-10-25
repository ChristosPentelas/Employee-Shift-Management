package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;

import java.time.LocalDate;

/**
 * Leave reasons are health and family information, so the endpoints decide who
 * sees which requests: everyone's only for supervisors, otherwise only your own
 * (F7). The nested UserResponse keeps the employee's password out (F3).
 */
public record LeaveRequestResponse(
        Integer id,
        LocalDate startDate,
        LocalDate endDate,
        String reason,
        LeaveStatus status,
        UserResponse user
) {
    public static LeaveRequestResponse from(LeaveRequest request) {
        return new LeaveRequestResponse(
                request.getId(),
                request.getStartDate(),
                request.getEndDate(),
                request.getReason(),
                request.getStatus(),
                request.getUser() == null ? null : UserResponse.from(request.getUser())
        );
    }
}
