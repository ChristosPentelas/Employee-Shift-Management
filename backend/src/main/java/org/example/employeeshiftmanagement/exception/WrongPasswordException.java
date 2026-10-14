package org.example.employeeshiftmanagement.exception;

/**
 * Thrown when a password change is sent with the wrong current password (B8).
 * ApiExceptionHandler answers 400 Bad Request.
 *
 * Not InvalidCredentialsException, and not 401: the caller's token is fine,
 * only a field of the form is wrong. The app ends the session on any 401 to a
 * request that carried a token (auth_client.dart), so a 401 here would log
 * the user out for a typo.
 *
 * No constructor that takes a message, like InvalidCredentialsException: the
 * text is fixed, so no password can ever end up in it.
 */
public class WrongPasswordException extends RuntimeException {
    public WrongPasswordException() {
        super("Current password is incorrect");
    }
}
