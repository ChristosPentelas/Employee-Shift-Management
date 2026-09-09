package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;

import java.time.LocalDate;

/**
 * Leave reasons are health and family information. This response still carries
 * every employee's leave to every caller - that is F7, and it needs the
 * authenticated principal from F1 to fix properly. What it no longer carries is
 * their password.
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
