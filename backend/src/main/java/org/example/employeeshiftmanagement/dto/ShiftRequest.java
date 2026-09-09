package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Body of both POST /api/v1/users/{userId}/shifts and
 * PUT /api/v1/shifts/{shiftId} - create and update take the same four fields,
 * so one record serves both rather than two identical classes.
 *
 * The employee is not in the body: on create it comes from the path, and on
 * update a shift cannot be reassigned to a different person.
 */
public record ShiftRequest(
        @NotNull(message = "Date is required")
        LocalDate date,

        @NotNull(message = "Start time is required")
        LocalTime startTime,

        @NotNull(message = "End time is required")
        LocalTime endTime,

        @NotBlank(message = "Position is required")
        String position
) {
}
