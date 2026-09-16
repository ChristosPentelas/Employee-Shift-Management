package org.example.employeeshiftmanagement.exception;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.oauth2.server.resource.web.access.BearerTokenAccessDeniedHandler;
import org.springframework.security.web.access.AccessDeniedHandler;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;

/**
 * The answer when we know who the caller is and they still may not do this -
 * an employee calling a supervisor-only endpoint, or reading someone else's
 * messages.
 *
 * This is where the AccessDeniedException that ApiExceptionHandler rethrows
 * ends up, which is why that rethrow matters: handling it in the advice would
 * bypass this and lose the 403.
 */
public class ProblemDetailAccessDeniedHandler implements AccessDeniedHandler {

    private final AccessDeniedHandler delegate = new BearerTokenAccessDeniedHandler();
    private final ProblemDetailWriter writer;

    public ProblemDetailAccessDeniedHandler(ObjectMapper objectMapper) {
        this.writer = new ProblemDetailWriter(objectMapper);
    }

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException accessDeniedException)
            throws IOException, ServletException {
        delegate.handle(request, response, accessDeniedException);
        writer.write(request, response, "You are not allowed to do this");
    }
}
