package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Body of POST /api/v1/users.
 *
 * Deliberately has no {@code id} and no {@code role}: the database assigns the
 * id, and the role is assigned server-side by
 * {@link org.example.employeeshiftmanagement.service.UserService#registerNewEmployee}.
 * A client that sends either one is ignored rather than obeyed.
 */
public record RegisterRequest(
        @NotBlank(message = "Name is required")
        String name,

        @NotBlank(message = "Email is required")
        @Email(message = "Email is not valid")
        String email,

        String phoneNumber,

        @NotBlank(message = "Password is required")
        @Size(min = 4, message = "Password must be at least 4 characters")
        String password
) {
}
