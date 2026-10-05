package org.example.employeeshiftmanagement.exception;

/**
 * Thrown when a login's email and password do not match a user.
 * ApiExceptionHandler answers 401 Unauthorized.
 *
 * There is no constructor that takes a message, on purpose: an unknown email
 * and a wrong password must get the same answer, or the difference tells the
 * caller which emails are registered (see UserService.authenticate).
 *
 * English, in the standard error shape. The app picks the Greek text it
 * shows from the 401 itself (login_screen.dart), so user-facing wording
 * stays in the UI and a second client is not stuck with our language (B2).
 */
public class InvalidCredentialsException extends RuntimeException {
    public InvalidCredentialsException() {
        super("Invalid email or password");
    }
}
