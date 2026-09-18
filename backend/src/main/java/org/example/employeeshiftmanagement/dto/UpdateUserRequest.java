package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.example.employeeshiftmanagement.validation.FieldLimits;

/**
 * Body of PUT /api/v1/users/{userId}.
 *
 * These three fields are exactly what
 * {@link org.example.employeeshiftmanagement.service.UserService#updateUser}
 * writes. Password and role are not editable through this endpoint, and the
 * DTO is what makes that contract visible instead of merely implied.
 */
public record UpdateUserRequest(
        @NotBlank(message = "Name is required")
        @Size(max = FieldLimits.TEXT, message = "Name must be at most {max} characters")
        String name,

        @NotBlank(message = "Email is required")
        @Email(message = "Email is not valid")
        @Size(max = FieldLimits.TEXT, message = "Email must be at most {max} characters")
        String email,

        @Size(max = FieldLimits.TEXT, message = "Phone number must be at most {max} characters")
        String phoneNumber
) {
}
