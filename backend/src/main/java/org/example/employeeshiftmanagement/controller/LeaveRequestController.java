package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.config.CurrentUser;
import org.example.employeeshiftmanagement.dto.CreateLeaveRequest;
import org.example.employeeshiftmanagement.dto.LeaveRequestResponse;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.service.LeaveRequestService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
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
    public ResponseEntity<?> createLeave(Authentication authentication,
                                        @Valid @RequestBody CreateLeaveRequest request) {
        try{
            // Always filed for the caller: an employee cannot file leave for a
            // colleague, and a client-sent userId is no longer read (F1 step 7b).
            LeaveRequest newRequest = leaveRequestService.createLeaveRequest(
                    CurrentUser.id(authentication), toLeaveDetails(request));
            return new ResponseEntity<>(LeaveRequestResponse.from(newRequest), HttpStatus.CREATED);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    @GetMapping("/users/{userId}/leaves")
    @PreAuthorize("#userId.toString() == authentication.name or hasRole('SUPERVISOR')")
    public ResponseEntity<?> getLeavesByUser(@PathVariable Integer userId) {
        try{
            return new ResponseEntity<>(toResponses(leaveRequestService.getLeavesByUser(userId)), HttpStatus.OK);
        }catch (RuntimeException e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }


    //endpoints for SUPERVISOR

    // Everyone's requests, reasons included - health and family information.
    // Employees read their own through /leaves/users/{userId}/leaves; the app
    // stopped calling this one in F1 step 7c, which is what let it close (F7).
    @GetMapping
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<List<LeaveRequestResponse>> getAllLeaves() {
        return ResponseEntity.ok(toResponses(leaveRequestService.getAllLeaveRequests()));
    }

    @GetMapping("/filter")
    @PreAuthorize("hasRole('SUPERVISOR')")
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
    @PreAuthorize("hasRole('SUPERVISOR')")
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
