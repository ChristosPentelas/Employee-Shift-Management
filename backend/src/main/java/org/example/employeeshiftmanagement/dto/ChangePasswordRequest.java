package org.example.employeeshiftmanagement.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Body of PUT /api/v1/users/me/password (B8).
 *
 * No user id: whose password changes comes from the token, never from the body.
 *
 * The two fields are checked differently on purpose. {@code newPassword} gets
 * the same rules as {@link RegisterRequest#password()}, because it is a new
 * password being chosen. {@code currentPassword} is only required: like
 * {@link LoginRequest}, a length rule here would lock out anyone whose
 * password predates a stricter rule - they could never change it to a
 * compliant one. Whether it is right is the service's question, not validation's.
 *
 * BCrypt's 72-byte limit is not here: {@code @Size} counts characters, not
 * bytes (see B20). UserService checks it.
 */
public record ChangePasswordRequest(
        @NotBlank(message = "Current password is required")
        String currentPassword,

        @NotBlank(message = "New password is required")
        @Size(min = 4, message = "New password must be at least 4 characters")
        String newPassword
) {
}
