package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.dto.CreateLeaveRequest;
import org.example.employeeshiftmanagement.dto.LeaveRequestResponse;
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
    public ResponseEntity<?> createLeave(@Valid @RequestBody CreateLeaveRequest request) {
        try{
            LeaveRequest newRequest =
                    leaveRequestService.createLeaveRequest(request.userId(), toLeaveDetails(request));
            return new ResponseEntity<>(LeaveRequestResponse.from(newRequest), HttpStatus.CREATED);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    @GetMapping("/users/{userId}/leaves")
    public ResponseEntity<?> getLeavesByUser(@PathVariable Integer userId) {
        try{
            return new ResponseEntity<>(toResponses(leaveRequestService.getLeavesByUser(userId)), HttpStatus.OK);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    //endpoints for SUPERVISOR

    @GetMapping
    public ResponseEntity<List<LeaveRequestResponse>> getAllLeaves() {
        return ResponseEntity.ok(toResponses(leaveRequestService.getAllLeaveRequests()));
    }

    @GetMapping("/filter")
    public ResponseEntity<?> filterLeaves(@RequestParam LeaveStatus status,
                                               @RequestParam(required = false) Integer userId) {
        try{
            if (userId != null) {
                return ResponseEntity.ok(toResponses(leaveRequestService.getLeavesByUserAndStatus(userId, status)));
            }else{
                return ResponseEntity.ok(toResponses(leaveRequestService.getLeavesByStatus(status)));
            }
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    @PutMapping("/{requestId}/status")
    public ResponseEntity<?> updateLeaveStatus(@PathVariable Integer requestId, @RequestParam LeaveStatus status) {
        try{
            LeaveRequest updated = leaveRequestService.updateLeaveRequest(requestId, status);
            return ResponseEntity.ok(LeaveRequestResponse.from(updated));
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    private static List<LeaveRequestResponse> toResponses(List<LeaveRequest> requests) {
        return requests.stream().map(LeaveRequestResponse::from).toList();
    }

    /** The employee and the PENDING status are both set by the service, not by the caller. */
    private LeaveRequest toLeaveDetails(CreateLeaveRequest request) {
        LeaveRequest leave = new LeaveRequest();
        leave.setStartDate(request.startDate());
        leave.setEndDate(request.endDate());
        leave.setReason(request.reason());
        return leave;
    }
}
