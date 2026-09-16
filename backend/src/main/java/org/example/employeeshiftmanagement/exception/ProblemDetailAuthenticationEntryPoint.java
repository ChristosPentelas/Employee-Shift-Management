package org.example.employeeshiftmanagement.exception;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.server.resource.web.BearerTokenAuthenticationEntryPoint;
import org.springframework.security.web.AuthenticationEntryPoint;
import tools.jackson.databind.ObjectMapper;

import java.io.IOException;

/**
 * The answer when the caller has not proved who they are: no token, an expired
 * one, or one whose signature does not check out.
 *
 * Spring Security's default sends the right status and header but an empty
 * body, so a 401 looked nothing like the other errors this API returns.
 *
 * It delegates first rather than reimplementing: the default sets the status
 * and the WWW-Authenticate header - the part of a 401 that tells a client *how*
 * to authenticate - without committing the response, so the body can still be
 * added afterwards.
 */
public class ProblemDetailAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final AuthenticationEntryPoint delegate = new BearerTokenAuthenticationEntryPoint();
    private final ProblemDetailWriter writer;

    public ProblemDetailAuthenticationEntryPoint(ObjectMapper objectMapper) {
        this.writer = new ProblemDetailWriter(objectMapper);
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authenticationException)
            throws IOException, ServletException {
        delegate.commence(request, response, authenticationException);
        // Deliberately vague: whether the token was missing, expired or forged is
        // not something an unauthenticated caller needs told.
        writer.write(request, response, "A valid access token is required");
    }
}
