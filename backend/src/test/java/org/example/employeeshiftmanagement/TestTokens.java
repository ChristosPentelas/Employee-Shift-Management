package org.example.employeeshiftmanagement;

import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

/**
 * Logged-in callers for the MockMvc controller tests.
 *
 * jwt().authorities(...) sets the authorities directly and skips
 * JwtConfig.jwtAuthenticationConverter. So these tests check the
 * @PreAuthorize rules, not that a real token's "role" claim becomes
 * ROLE_... - SecurityIntegrationTest does that with real tokens.
 */
final class TestTokens {

    private TestTokens() {
    }

    static RequestPostProcessor supervisor() {
        return jwt().authorities(new SimpleGrantedAuthority("ROLE_SUPERVISOR"));
    }

    static RequestPostProcessor employee() {
        return jwt().authorities(new SimpleGrantedAuthority("ROLE_EMPLOYEE"));
    }
}
