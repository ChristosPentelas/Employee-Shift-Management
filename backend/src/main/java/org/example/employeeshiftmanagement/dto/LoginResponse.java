package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.User;

/**
 * What a successful login returns: the fields of UserResponse plus the token.
 *
 * Flat rather than {"user": {...}, "token": "..."} on purpose: the Flutter app
 * reads the user fields from the top level and ignores keys it does not know,
 * so adding "token" here does not break it (F1 step 2). Still no password.
 */
public record LoginResponse(
        Integer id,
        String name,
        String email,
        String phoneNumber,
        String role,
        String token
) {
    public static LoginResponse from(User user, String token) {
        return new LoginResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhoneNumber(),
                user.getRole(),
                token
        );
    }
}
