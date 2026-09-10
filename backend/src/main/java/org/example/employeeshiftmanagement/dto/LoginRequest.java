package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Body of POST /api/v1/users/login.
 *
 * Only checks that both fields were sent. Password rules (length etc.) belong
 * to {@link RegisterRequest}: enforcing them here would lock out any existing
 * user whose password predates a stricter rule. Whether the credentials are
 * right is the controller's 401, not a validation error.
 */
public record LoginRequest(
        @NotBlank(message = "Email is required")
        String email,

        @NotBlank(message = "Password is required")
        String password
) {
}
