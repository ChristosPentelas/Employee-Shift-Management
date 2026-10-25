package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.service.LeaveDecisionResult;

import java.time.LocalDate;

/**
 * Body of PUT /api/v1/leaves/{id}/status: the answered request, the same
 * fields as LeaveRequestResponse, plus how many of the employee's shifts the
 * approval removed (B31), so the app can tell the supervisor.
 *
 * Flat, not {"request": {...}, "removedShifts": 2}: a client that read this
 * body before B31 still finds every field where it was. Not a field on
 * LeaveRequestResponse either, which the lists use, where it means nothing.
 * The fields are repeated rather than unwrapped with Jackson's
 * @JsonUnwrapped, so the shape on the wire is the one written here.
 */
public record LeaveDecisionResponse(
        Integer id,
        LocalDate startDate,
        LocalDate endDate,
        String reason,
        LeaveStatus status,
        UserResponse user,
        int removedShifts
) {
    public static LeaveDecisionResponse from(LeaveDecisionResult result) {
        LeaveRequestResponse request = LeaveRequestResponse.from(result.request());
        return new LeaveDecisionResponse(
                request.id(),
                request.startDate(),
                request.endDate(),
                request.reason(),
                request.status(),
                request.user(),
                result.removedShifts()
        );
    }
}
