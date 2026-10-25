package org.example.employeeshiftmanagement.exception;

import java.net.URI;

/**
 * The "type" values an error body can carry besides about:blank (B31).
 *
 * RFC 9457 makes "type" the field a client reads to tell one kind of problem
 * from another, where "detail" is text for a person. A client only needs one
 * when it must react differently to two errors with the same status: the app
 * shows one message for an overlapping shift and another for a leave day, and
 * both are 409.
 *
 * URNs, not https links: nothing is published at these addresses, and a link
 * would suggest there is a page to open.
 *
 * The app has a copy of every value here. Changing one breaks it.
 */
public final class ProblemTypes {

    /** The employee has approved leave on the shift's date. */
    public static final URI EMPLOYEE_ON_LEAVE = URI.create("urn:shift-manager:problem:employee-on-leave");

    private ProblemTypes() {
    }
}
