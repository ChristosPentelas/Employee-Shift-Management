package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.config.CurrentUser;
import org.example.employeeshiftmanagement.dto.CreateLeaveRequest;
import org.example.employeeshiftmanagement.dto.LeaveRequestResponse;
import org.example.employeeshiftmanagement.dto.PageResponse;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.example.employeeshiftmanagement.service.LeaveRequestService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

/**
 * Every list here is one page, latest leave first: {@code ?page=0&size=20}
 * (F9). See NewsItemController.getAllNews for the defaults and the cap.
 */
@RestController
@RequestMapping("/api/v1/leaves")
public class LeaveRequestController {

    private final LeaveRequestService leaveRequestService;

    public LeaveRequestController(LeaveRequestService leaveRequestService) {
        this.leaveRequestService = leaveRequestService;
    }

    //endpoints for EMPLOYEES

    @PostMapping
    public ResponseEntity<LeaveRequestResponse> createLeave(Authentication authentication,
                                        @Valid @RequestBody CreateLeaveRequest request) {
        // Always filed for the caller: an employee cannot file leave for a
        // colleague, and a client-sent userId is no longer read (F1 step 7b).
        LeaveRequest newRequest = leaveRequestService.createLeaveRequest(
                CurrentUser.id(authentication), toLeaveDetails(request));
        return new ResponseEntity<>(LeaveRequestResponse.from(newRequest), HttpStatus.CREATED);
    }


    @GetMapping("/users/{userId}/leaves")
    @PreAuthorize("#userId.toString() == authentication.name or hasRole('SUPERVISOR')")
    public ResponseEntity<PageResponse<LeaveRequestResponse>> getLeavesByUser(@PathVariable Integer userId,
                                                                              Pageable pageable) {
        return ResponseEntity.ok(toResponses(leaveRequestService.getLeavesByUser(userId, pageable)));
    }


    //endpoints for SUPERVISOR

    // Everyone's requests, reasons included - health and family information.
    // Employees read their own through /leaves/users/{userId}/leaves; the app
    // stopped calling this one in F1 step 7c, which is what let it close (F7).
    @GetMapping
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<PageResponse<LeaveRequestResponse>> getAllLeaves(Pageable pageable) {
        return ResponseEntity.ok(toResponses(leaveRequestService.getAllLeaveRequests(pageable)));
    }

    @GetMapping("/filter")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<PageResponse<LeaveRequestResponse>> filterLeaves(@RequestParam LeaveStatus status,
                                               @RequestParam(required = false) Integer userId,
                                               Pageable pageable) {
        if (userId != null) {
            return ResponseEntity.ok(toResponses(leaveRequestService.getLeavesByUserAndStatus(userId, status, pageable)));
        }else{
            return ResponseEntity.ok(toResponses(leaveRequestService.getLeavesByStatus(status, pageable)));
        }
    }


    @PutMapping("/{requestId}/status")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<LeaveRequestResponse> updateLeaveStatus(@PathVariable Integer requestId,
                                                                  @RequestParam LeaveStatus status) {
        LeaveRequest updated = leaveRequestService.updateLeaveRequest(requestId, status);
        return ResponseEntity.ok(LeaveRequestResponse.from(updated));
    }

    private static PageResponse<LeaveRequestResponse> toResponses(Page<LeaveRequest> requests) {
        return PageResponse.from(requests, LeaveRequestResponse::from);
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
