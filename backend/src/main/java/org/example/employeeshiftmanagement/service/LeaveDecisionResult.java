package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.model.LeaveRequest;

/**
 * What answering a leave request did: the request as now stored, and how many
 * of the employee's shifts the approval removed (B31) - 0 for a rejection.
 *
 * A plain pair for the controller, which turns it into LeaveDecisionResponse;
 * not a DTO, since it holds the entity.
 */
public record LeaveDecisionResult(LeaveRequest request, int removedShifts) {
}
