package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Sort;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The shift-overlap rule (F30), as a plain unit test: no Spring, no Docker.
 *
 * The repository is a mock that returns the employee's "nearby" shifts - the
 * day before to the day after, which is what ShiftService asks for. Each test
 * names the stored shift it puts there and the one it tries to save.
 */
class ShiftServiceTest {

    private static final LocalDate DAY = LocalDate.of(2026, 9, 29);

    private final ShiftRepository shiftRepository = mock(ShiftRepository.class);
    private final UserService userService = mock(UserService.class);
    private final ShiftService shiftService = new ShiftService(shiftRepository, userService);

    @BeforeEach
    void employeeSevenExists() {
        when(userService.findUserById(7)).thenReturn(TestUsers.employee());
        when(shiftRepository.save(any(Shift.class))).thenAnswer(call -> call.getArgument(0));
    }

    private static Shift shift(Integer id, LocalDate date, String start, String end) {
        Shift shift = new Shift();
        shift.setId(id);
        shift.setDate(date);
        shift.setStartTime(LocalTime.parse(start));
        shift.setEndTime(LocalTime.parse(end));
        shift.setPosition("Ταμείο");
        shift.setUser(TestUsers.employee());
        return shift;
    }

    /** What the employee already has around DAY, as the repository would return it. */
    private void stored(Shift... shifts) {
        when(shiftRepository.findByUserIdAndDateBetween(
                eq(7), eq(DAY.minusDays(1)), eq(DAY.plusDays(1)), any(Sort.class)))
                .thenReturn(List.of(shifts));
    }

    @Test
    void aShiftThatOverlapsAnotherOnTheSameDayIsRejected() {
        stored(shift(12, DAY, "09:00", "13:00"));

        ConflictException e = assertThrows(ConflictException.class,
                () -> shiftService.createShift(7, shift(null, DAY, "12:00", "17:00")));

        assertEquals("Overlaps shift 12 on 2026-09-29, 09:00-13:00", e.getMessage());
        verify(shiftRepository, never()).save(any());
    }

    @Test
    void aShiftThatStartsWhenTheLastOneEndsIsAllowed() {
        stored(shift(12, DAY, "09:00", "13:00"));

        shiftService.createShift(7, shift(null, DAY, "13:00", "17:00"));

        verify(shiftRepository).save(any(Shift.class));
    }

    @Test
    void lastNightsShiftRunningIntoThisMorningIsAnOverlap() {
        // 28th 22:00 until 29th 06:00
        stored(shift(12, DAY.minusDays(1), "22:00", "06:00"));

        assertThrows(ConflictException.class,
                () -> shiftService.createShift(7, shift(null, DAY, "05:00", "09:00")));
    }

    @Test
    void aNightShiftRunningIntoTomorrowsEarlyShiftIsAnOverlap() {
        stored(shift(12, DAY.plusDays(1), "05:00", "09:00"));

        // 29th 22:00 until 30th 06:00
        assertThrows(ConflictException.class,
                () -> shiftService.createShift(7, shift(null, DAY, "22:00", "06:00")));
    }

    @Test
    void aNightShiftEndingWhenTomorrowsShiftStartsIsAllowed() {
        stored(shift(12, DAY.plusDays(1), "06:00", "14:00"));

        shiftService.createShift(7, shift(null, DAY, "22:00", "06:00"));

        verify(shiftRepository).save(any(Shift.class));
    }

    @Test
    void movingAShiftDoesNotClashWithItsOwnOldTimes() {
        Shift existing = shift(12, DAY, "09:00", "13:00");
        stored(existing);
        when(shiftRepository.findById(12)).thenReturn(Optional.of(existing));

        // An hour later: overlaps 09:00-13:00, but that is this same shift.
        Shift moved = shiftService.updateShift(12, shift(null, DAY, "10:00", "14:00"));

        assertEquals(LocalTime.of(10, 0), moved.getStartTime());
    }

    @Test
    void movingAShiftOntoAnotherIsRejected() {
        Shift existing = shift(12, DAY, "09:00", "13:00");
        stored(existing, shift(13, DAY, "15:00", "19:00"));
        when(shiftRepository.findById(12)).thenReturn(Optional.of(existing));

        ConflictException e = assertThrows(ConflictException.class,
                () -> shiftService.updateShift(12, shift(null, DAY, "14:00", "18:00")));

        assertEquals("Overlaps shift 13 on 2026-09-29, 15:00-19:00", e.getMessage());
        // Refused before anything changed, not half-way through.
        assertEquals(LocalTime.of(9, 0), existing.getStartTime());
        verify(shiftRepository, never()).save(any());
    }
}
