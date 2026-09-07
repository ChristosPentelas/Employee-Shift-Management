package org.example.employeeshiftmanagement.controller;

import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
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
    public ResponseEntity<?> createShift(@PathVariable Integer userId, @RequestBody Shift shift) {
        try {
            Shift newShift = shiftService.createShift(userId, shift);
            return new ResponseEntity<>(newShift, HttpStatus.CREATED);
        } catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping("/shifts")
    public ResponseEntity<List<Shift>> getAllShifts(){
        return ResponseEntity.ok(shiftService.getAllShifts());
    }

    @GetMapping("/shifts/users/{userId}")
    public ResponseEntity<?> getShiftsByUser(@PathVariable Integer userId) {
        try {
            List<Shift> shifts = shiftService.getShiftsByEmployee(userId);
            return ResponseEntity.ok(shifts);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @PutMapping("/shifts/{shiftId}")
    public ResponseEntity<?> updateShift(@PathVariable Integer shiftId, @RequestBody Shift shiftDetails) {
        try {
            Shift updatedShift = shiftService.updateShift(shiftId, shiftDetails);
            return ResponseEntity.ok(updatedShift);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @DeleteMapping("/shifts/{shiftId}")
    public ResponseEntity<?> deleteShift(@PathVariable Integer shiftId) {
        try {
            shiftService.deleteShift(shiftId);
            return ResponseEntity.noContent().build();
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping("/users/{userId}/schedule")
    public ResponseEntity<?> getSchedule(@PathVariable Integer userId,
                                         //We use RequestParam to filter by date, as defined by REST standards
                                         @RequestParam @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate start,
                                         @RequestParam @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate end) {
        try{
            List<Shift> schedule = shiftService.getSchedule(userId, start, end);
            return ResponseEntity.ok(schedule);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }

    }
}
