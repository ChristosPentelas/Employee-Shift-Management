package org.example.employeeshiftmanagement.controller;

import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.service.LeaveRequestService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/leaves")
public class LeaveRequestController {

    private final LeaveRequestService leaveRequestService;

    public LeaveRequestController(LeaveRequestService leaveRequestService) {
        this.leaveRequestService = leaveRequestService;
    }

    //endpoints for EMPLOYEES

    @PostMapping
    public ResponseEntity<?> createLeave(@RequestBody LeaveRequest request) {
        try{
            LeaveRequest newRequest = leaveRequestService.createLeaveRequest(request);
            return new ResponseEntity<>(newRequest, HttpStatus.CREATED);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    @GetMapping("/users/{userId}/leaves")
    public ResponseEntity<?> getLeavesByUser(@PathVariable Integer userId) {
        try{
            List<LeaveRequest> leavesByUser = leaveRequestService.getLeavesByUser(userId);
            return new ResponseEntity<>(leavesByUser, HttpStatus.OK);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    //endpoints for SUPERVISOR

    @GetMapping
    public ResponseEntity<List<LeaveRequest>> getAllLeaves() {
        return ResponseEntity.ok(leaveRequestService.getAllLeaveRequests());
    }

    @GetMapping("/filter")
    public ResponseEntity<?> filterLeaves(@RequestParam LeaveStatus status,
                                               @RequestParam(required = false) Integer userId) {
        try{
            if (userId != null) {
                return ResponseEntity.ok(leaveRequestService.getLeavesByUserAndStatus(userId, status));
            }else{
                return ResponseEntity.ok(leaveRequestService.getLeavesByStatus(status));
            }
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    @PutMapping("/{requestId}/status")
    public ResponseEntity<?> updateLeaveStatus(@PathVariable Integer requestId, @RequestParam LeaveStatus status) {
        try{
            LeaveRequest updated = leaveRequestService.updateLeaveRequest(requestId, status);
            return ResponseEntity.ok(updated);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


}
