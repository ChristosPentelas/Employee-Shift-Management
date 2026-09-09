package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.User;

/**
 * Shared fixtures for the controller tests.
 *
 * Every user here has a password set on purpose: these entities are what the
 * mocked services hand back, so if a controller ever serialises the entity
 * instead of a response DTO, the password is right there to be caught.
 */
final class TestUsers {

    private TestUsers() {
    }

    static User employee() {
        return user(7, "Worker", "worker@example.com", "EMPLOYEE");
    }

    static User supervisor() {
        return user(9, "Boss", "boss@example.com", "SUPERVISOR");
    }

    private static User user(Integer id, String name, String email, String role) {
        User user = new User();
        user.setId(id);
        user.setName(name);
        user.setEmail(email);
        user.setPhoneNumber("1234567890");
        user.setPassword("secret123");
        user.setRole(role);
        return user;
    }
}
