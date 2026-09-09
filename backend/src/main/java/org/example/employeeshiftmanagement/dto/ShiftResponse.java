package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.Shift;

import java.time.LocalDate;
import java.time.LocalTime;

/** The "user" key matches what Shift.fromJson already reads on the Flutter side. */
public record ShiftResponse(
        Integer id,
        LocalDate date,
        LocalTime startTime,
        LocalTime endTime,
        String position,
        UserResponse user
) {
    public static ShiftResponse from(Shift shift) {
        return new ShiftResponse(
                shift.getId(),
                shift.getDate(),
                shift.getStartTime(),
                shift.getEndTime(),
                shift.getPosition(),
                shift.getUser() == null ? null : UserResponse.from(shift.getUser())
        );
    }
}
