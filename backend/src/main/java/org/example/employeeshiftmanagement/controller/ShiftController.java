package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.dto.DateRangeQuery;
import org.example.employeeshiftmanagement.dto.PageResponse;
import org.example.employeeshiftmanagement.dto.ShiftRequest;
import org.example.employeeshiftmanagement.dto.ShiftResponse;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/")//in the shift controller we have two different types of routes(from users and from shifts)
public class ShiftController {

    private final ShiftService shiftService;

    public ShiftController(ShiftService shiftService) {
        this.shiftService = shiftService;
    }

    @PostMapping("/users/{userId}/shifts")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<ShiftResponse> createShift(@PathVariable Integer userId,
                                                     @Valid @RequestBody ShiftRequest request) {
        Shift newShift = shiftService.createShift(userId, toShift(request));
        return new ResponseEntity<>(ShiftResponse.from(newShift), HttpStatus.CREATED);
    }

    /**
     * Everyone's shifts in {@code ?start=&end=} (both required, at most
     * ValidDateRange.MAX_DAYS days), in calendar order. Employees read their
     * own through /users/{userId}/schedule.
     *
     * A date range instead of pages (F9): the supervisor's calendar needs every
     * shift of the month it shows, so page 0 of "all shifts ever" was no use.
     */
    @GetMapping("/shifts")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<List<ShiftResponse>> getAllShifts(@Valid DateRangeQuery range){
        return ResponseEntity.ok(toResponses(shiftService.getAllShifts(range.start(), range.end())));
    }

    /** One employee's shift history, one page at a time, latest first (F9). */
    @GetMapping("/shifts/users/{userId}")
    @PreAuthorize("#userId.toString() == authentication.name or hasRole('SUPERVISOR')")
    public ResponseEntity<PageResponse<ShiftResponse>> getShiftsByUser(@PathVariable Integer userId,
                                                                       Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(
                shiftService.getShiftsByEmployee(userId, pageable), ShiftResponse::from));
    }

    @PutMapping("/shifts/{shiftId}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<ShiftResponse> updateShift(@PathVariable Integer shiftId,
                                                     @Valid @RequestBody ShiftRequest request) {
        Shift updatedShift = shiftService.updateShift(shiftId, toShift(request));
        return ResponseEntity.ok(ShiftResponse.from(updatedShift));
    }

    @DeleteMapping("/shifts/{shiftId}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<Void> deleteShift(@PathVariable Integer shiftId) {
        shiftService.deleteShift(shiftId);
        return ResponseEntity.noContent().build();
    }

    /** Same range rules as GET /shifts. */
    @GetMapping("/users/{userId}/schedule")
    @PreAuthorize("#userId.toString() == authentication.name or hasRole('SUPERVISOR')")
    public ResponseEntity<List<ShiftResponse>> getSchedule(@PathVariable Integer userId,
                                         //We filter by date with query parameters (?start=&end=), as defined by REST standards
                                         @Valid DateRangeQuery range) {
        return ResponseEntity.ok(toResponses(shiftService.getSchedule(userId, range.start(), range.end())));
    }

    private static List<ShiftResponse> toResponses(List<Shift> shifts) {
        return shifts.stream().map(ShiftResponse::from).toList();
    }

    private Shift toShift(ShiftRequest request) {
        Shift shift = new Shift();
        shift.setDate(request.date());
        shift.setStartTime(request.startTime());
        shift.setEndTime(request.endTime());
        shift.setPosition(request.position());
        return shift;
    }
}
