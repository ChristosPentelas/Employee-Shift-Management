package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.User;

/**
 * The only shape in which a user leaves this API.
 *
 * Note what is absent: {@code password}. The User entity has no
 * {@code @JsonIgnore} on it, so any endpoint that serialises the entity hands
 * the caller a password. Going through this record is what prevents that.
 */
public record UserResponse(
        Integer id,
        String name,
        String email,
        String phoneNumber,
        String role
) {
    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhoneNumber(),
                user.getRole()
        );
    }
}
