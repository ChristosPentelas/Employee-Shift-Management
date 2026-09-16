package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.dto.ShiftRequest;
import org.example.employeeshiftmanagement.dto.ShiftResponse;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
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
    public ResponseEntity<?> createShift(@PathVariable Integer userId,
                                         @Valid @RequestBody ShiftRequest request) {
        try {
            Shift newShift = shiftService.createShift(userId, toShift(request));
            return new ResponseEntity<>(ShiftResponse.from(newShift), HttpStatus.CREATED);
        } catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    /** Everyone's shifts. Employees read their own through /users/{userId}/schedule. */
    @GetMapping("/shifts")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<List<ShiftResponse>> getAllShifts(){
        return ResponseEntity.ok(toResponses(shiftService.getAllShifts()));
    }

    @GetMapping("/shifts/users/{userId}")
    @PreAuthorize("#userId.toString() == authentication.name or hasRole('SUPERVISOR')")
    public ResponseEntity<?> getShiftsByUser(@PathVariable Integer userId) {
        try {
            return ResponseEntity.ok(toResponses(shiftService.getShiftsByEmployee(userId)));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @PutMapping("/shifts/{shiftId}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<?> updateShift(@PathVariable Integer shiftId,
                                         @Valid @RequestBody ShiftRequest request) {
        try {
            Shift updatedShift = shiftService.updateShift(shiftId, toShift(request));
            return ResponseEntity.ok(ShiftResponse.from(updatedShift));
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @DeleteMapping("/shifts/{shiftId}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<?> deleteShift(@PathVariable Integer shiftId) {
        try {
            shiftService.deleteShift(shiftId);
            return ResponseEntity.noContent().build();
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping("/users/{userId}/schedule")
    @PreAuthorize("#userId.toString() == authentication.name or hasRole('SUPERVISOR')")
    public ResponseEntity<?> getSchedule(@PathVariable Integer userId,
                                         //We use RequestParam to filter by date, as defined by REST standards
                                         @RequestParam @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate start,
                                         @RequestParam @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate end) {
        try{
            return ResponseEntity.ok(toResponses(shiftService.getSchedule(userId, start, end)));
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }

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
