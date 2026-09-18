package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.example.employeeshiftmanagement.validation.FieldLimits;
import org.example.employeeshiftmanagement.validation.ValidShiftTimes;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Body of both POST /api/v1/users/{userId}/shifts and
 * PUT /api/v1/shifts/{shiftId} - create and update take the same four fields,
 * so one record serves both rather than two identical classes.
 *
 * The employee is not in the body: on create it comes from the path, and on
 * update a shift cannot be reassigned to a different person.
 *
 * endTime may be earlier than startTime - that is an overnight shift ending
 * the next day - but not equal to it; checked by the ValidShiftTimes
 * annotation on the record.
 */
@ValidShiftTimes
public record ShiftRequest(
        @NotNull(message = "Date is required")
        LocalDate date,

        @NotNull(message = "Start time is required")
        LocalTime startTime,

        @NotNull(message = "End time is required")
        LocalTime endTime,

        @NotBlank(message = "Position is required")
        @Size(max = FieldLimits.TEXT, message = "Position must be at most {max} characters")
        String position
) {
}
