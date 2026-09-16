package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

/**
 * Body of POST /api/v1/leaves.
 *
 * No userId either: the request is always filed for the caller, taken from
 * their token (F1 step 7b). No status field: a new leave request is always PENDING, decided by
 * LeaveRequestService. Letting the client send one meant an employee could file
 * a request that was already APPROVED.
 */
public record CreateLeaveRequest(
        @NotNull(message = "Start date is required")
        LocalDate startDate,

        @NotNull(message = "End date is required")
        LocalDate endDate,

        @NotBlank(message = "Reason is required")
        String reason
) {
}
