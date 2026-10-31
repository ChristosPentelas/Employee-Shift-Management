package org.example.employeeshiftmanagement.exception;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The one place that turns an exception into an HTTP response (F14).
 *
 * Before this class every controller method wrapped itself in try/catch and
 * guessed a status code, so the same missing user answered 404 on GET, 400 on
 * PUT and 500 on DELETE - and a real bug answered 404 like everything else.
 * A @RestControllerAdvice is Spring's answer to that duplication: it applies to
 * every controller in the application, so the rule is written once.
 *
 * Bodies are RFC 9457 ProblemDetail - the standard error shape, already in
 * Spring, so no client-specific format to invent or document:
 *
 * {"title":"Not Found","status":404,
 *  "detail":"User not found","instance":"/api/v1/users/7"}
 *
 * No "type" there: Spring leaves it out when it is about:blank, the default,
 * which is what a missing type means. Only a clash the client must tell
 * apart sends one (ProblemTypes, B31).
 *
 * Extending ResponseEntityExceptionHandler is what gives sensible answers to
 * malformed JSON, an unknown enum value or a missing request parameter; on its
 * own an advice would leave those to fall through as 500s.
 */
@RestControllerAdvice
public class ApiExceptionHandler extends ResponseEntityExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    /** The record does not exist. The message is written for a person to read. */
    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }

    /**
     * The request is valid on its own but clashes with stored data (F30).
     * A clash with a problem type keeps it in the body, so the client can
     * tell it from the others (B31).
     */
    @ExceptionHandler(ConflictException.class)
    public ProblemDetail handleConflict(ConflictException e) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.getMessage());
        if (e.getType() != null) {
            problem.setType(e.getType());
        }
        return problem;
    }

    /**
     * A rule a service checked against stored data (B74). The same body as
     * handleMethodArgumentNotValid below, so the client cannot tell - and
     * need not care - which layer refused the request.
     */
    @ExceptionHandler(FieldValidationException.class)
    public ProblemDetail handleFieldValidation(FieldValidationException e) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Validation failed");
        problem.setProperty("errors", e.getErrors());
        return problem;
    }

    /** A failed login (F16 step 16b; until then the controller built this 401 itself). */
    @ExceptionHandler(InvalidCredentialsException.class)
    public ProblemDetail handleInvalidCredentials(InvalidCredentialsException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, e.getMessage());
    }

    /**
     * A password change with the wrong current password (B8). 400, not 401:
     * the token was accepted, so the app must not treat this as a logout.
     */
    @ExceptionHandler(WrongPasswordException.class)
    public ProblemDetail handleWrongPassword(WrongPasswordException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, e.getMessage());
    }

    /**
     * A locked account (B56). A ResponseEntity rather than a bare ProblemDetail,
     * since only it can carry the Retry-After header; Spring still fills in the
     * body's "instance".
     *
     * Retry-After is a whole number of seconds (RFC 9110), rounded up and at
     * least 1: rounding 90.4 s down, or 0.4 s to "0", would send the client
     * back while the lock is still on.
     */
    @ExceptionHandler(TooManyAttemptsException.class)
    public ResponseEntity<ProblemDetail> handleTooManyAttempts(TooManyAttemptsException e) {
        long seconds = Math.max(1, Math.ceilDiv(e.getRetryAfter().toMillis(), 1000));
        return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                .header(HttpHeaders.RETRY_AFTER, String.valueOf(seconds))
                .body(ProblemDetail.forStatusAndDetail(HttpStatus.TOO_MANY_REQUESTS, e.getMessage()));
    }

    /**
     * Re-thrown on purpose, so Spring Security keeps deciding 401 vs 403.
     *
     * Without this method the catch-all below would swallow the
     * AuthorizationDeniedException that @PreAuthorize throws and answer 500,
     * turning every refused request into "the server is broken". Spring picks
     * the most specific handler, so this one wins over handleAnythingElse.
     *
     * Throwing from a handler makes Spring continue with the original
     * exception, which then reaches Spring Security's ExceptionTranslationFilter.
     */
    @ExceptionHandler(AccessDeniedException.class)
    public void rethrowAccessDenied(AccessDeniedException e) {
        throw e;
    }

    /**
     * Anything not named above is a bug or an outage, never the caller's fault.
     *
     * IllegalStateException included: until B20 it had its own 400 handler,
     * which blamed the caller for any library's IllegalStateException and
     * sent that library's text to the client.
     *
     * The message deliberately does not reach the client: exception text names
     * tables, columns, file paths and library internals. It goes to the log,
     * where the people who can fix it will look.
     */
    @ExceptionHandler(Exception.class)
    public ProblemDetail handleAnythingElse(Exception e) {
        log.error("Unhandled exception", e);
        return ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR, "Something went wrong");
    }

    /**
     * Failed @Valid checks, with the field messages attached (B1).
     *
     * The DTOs have carried messages like "Email is required" all along, but
     * Spring Boot leaves binding errors out of the default error body
     * (server.error.include-binding-errors=never), so the app got a bare 400
     * and could not say which field was wrong.
     *
     * English on purpose: the server sends a code and a name the client can act
     * on, and the Flutter app decides what the user reads (B2).
     */
    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException e, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {

        // LinkedHashMap keeps the fields in the order they were declared, so the
        // same bad request always produces the same body.
        Map<String, String> errors = new LinkedHashMap<>();
        for (FieldError fieldError : e.getBindingResult().getFieldErrors()) {
            String message = fieldError.getDefaultMessage();
            // putIfAbsent: two failed rules on one field would otherwise show
            // whichever ran last. The first is enough to fix the request.
            errors.putIfAbsent(fieldError.getField(), message != null ? message : "Invalid value");
        }

        ProblemDetail body = e.getBody();
        body.setDetail("Validation failed");
        body.setProperty("errors", errors);

        return handleExceptionInternal(e, body, headers, status, request);
    }
}
