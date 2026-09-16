package org.example.employeeshiftmanagement.exception;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ProblemDetail;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;

/**
 * Writes a ProblemDetail body straight onto the servlet response.
 *
 * Needed because Spring Security answers 401 and 403 from inside the filter
 * chain, before any controller or @ControllerAdvice exists. There is no handler
 * method to return a value from, so the JSON is serialised by hand here.
 *
 * Package-private and shared by the two handlers next to it, so the error shape
 * is still defined in one place.
 */
final class ProblemDetailWriter {

    private final ObjectMapper objectMapper;

    ProblemDetailWriter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /**
     * Keeps whatever status the caller already put on the response: a bearer
     * token can fail as 401 (invalid or expired) or 400 (malformed header), and
     * Spring Security has already worked out which.
     */
    void write(HttpServletRequest request, HttpServletResponse response, String detail) throws IOException {
        // Nothing can be added once the response has gone out; writing anyway
        // would throw and bury the real 401 under a 500.
        if (response.isCommitted()) {
            return;
        }

        ProblemDetail body = ProblemDetail.forStatusAndDetail(
                HttpStatus.valueOf(response.getStatus()), detail);
        body.setInstance(URI.create(request.getRequestURI()));

        // No charset parameter: application/problem+json is UTF-8 by definition,
        // and Jackson writes UTF-8 to an OutputStream. Adding it would make this
        // header differ from the one Spring MVC sets for the same body.
        response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
        objectMapper.writeValue(response.getOutputStream(), body);
    }
}
