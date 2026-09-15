package org.example.employeeshiftmanagement;

import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

/**
 * Logged-in callers for the MockMvc controller tests.
 *
 * Their subjects match TestUsers (employee 7, supervisor 9), because ownership
 * rules compare the token's subject with the ids in the request.
 *
 * jwt().authorities(...) sets the authorities directly and skips
 * JwtConfig.jwtAuthenticationConverter. So these tests check the
 * @PreAuthorize rules, not that a real token's "role" claim becomes
 * ROLE_... - SecurityIntegrationTest does that with real tokens.
 */
final class TestTokens {

    static final int EMPLOYEE_ID = 7;
    static final int SUPERVISOR_ID = 9;

    private TestTokens() {
    }

    static RequestPostProcessor supervisor() {
        return jwt()
                .jwt(token -> token.subject(String.valueOf(SUPERVISOR_ID)))
                .authorities(new SimpleGrantedAuthority("ROLE_SUPERVISOR"));
    }

    static RequestPostProcessor employee() {
        return jwt()
                .jwt(token -> token.subject(String.valueOf(EMPLOYEE_ID)))
                .authorities(new SimpleGrantedAuthority("ROLE_EMPLOYEE"));
    }
}
