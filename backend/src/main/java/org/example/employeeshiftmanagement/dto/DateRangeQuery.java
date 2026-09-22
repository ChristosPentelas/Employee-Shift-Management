package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotNull;
import org.example.employeeshiftmanagement.validation.ValidDateRange;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;

/**
 * The {@code ?start=YYYY-MM-DD&end=YYYY-MM-DD} of the shift calendars, both
 * days included.
 *
 * These endpoints are bounded by a date range instead of pages (F9): a calendar
 * needs every shift of the month it shows, and page 1 of "all shifts" would
 * leave most of its days empty. The range must be short enough that "every
 * shift in it" stays small - see ValidDateRange.
 *
 * Bound from query parameters, not a JSON body: Spring fills the record from
 * parameters of the same name, and @Valid then runs the same checks as on a
 * body, so a bad range gets the same 400 with field errors (B1).
 */
@ValidDateRange
public record DateRangeQuery(
        @NotNull(message = "Start date is required")
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        LocalDate start,

        @NotNull(message = "End date is required")
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        LocalDate end
) {
}
