package org.example.employeeshiftmanagement.config;

import org.springframework.security.core.Authentication;

/**
 * Who is making the request, according to their token - never according to
 * an id the client sent.
 *
 * TokenService puts the user's id in the token's subject, and Spring exposes
 * the subject as the authentication's name. The same value is what
 * {@code authentication.name} means inside {@code @PreAuthorize} rules.
 */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static Integer id(Authentication authentication) {
        return Integer.valueOf(authentication.getName());
    }
}
