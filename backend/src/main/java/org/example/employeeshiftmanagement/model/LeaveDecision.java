package org.example.employeeshiftmanagement.model;

/**
 * What a supervisor can answer to a leave request (B63).
 *
 * A type of its own rather than LeaveStatus, which also has PENDING: with
 * this as the endpoint's parameter, "?status=PENDING" cannot be bound at all
 * and Spring answers 400 before any code of ours runs. No check to write,
 * and none to forget.
 */
public enum LeaveDecision {
    APPROVED,
    REJECTED;

    public LeaveStatus toStatus() {
        return switch (this) {
            case APPROVED -> LeaveStatus.APPROVED;
            case REJECTED -> LeaveStatus.REJECTED;
        };
    }
}
