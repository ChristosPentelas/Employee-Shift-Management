package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

import java.util.Base64;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JwtConfigTest {

    // The app must refuse to start with a signing key that is missing or too weak.

    @Test
    void aMissingSecretIsRejected() {
        assertThrows(IllegalStateException.class, () -> JwtConfig.signingKey(""));
    }

    @Test
    void aSecretThatIsNotBase64IsRejected() {
        assertThrows(IllegalStateException.class,
                () -> JwtConfig.signingKey("paste_your_generated_value_here!"));
    }

    @Test
    void aSecretShorterThan32BytesIsRejected() {
        String thirtyOneBytes = Base64.getEncoder().encodeToString(new byte[31]);

        assertThrows(IllegalStateException.class, () -> JwtConfig.signingKey(thirtyOneBytes));
    }

    @Test
    void aSecretOfExactly32BytesIsAccepted() {
        String thirtyTwoBytes = Base64.getEncoder().encodeToString(new byte[32]);

        assertDoesNotThrow(() -> JwtConfig.signingKey(thirtyTwoBytes));
    }

    // The token's role claim must become the authority hasRole() checks.

    /**
     * The ROLE_ authorities a token with this role claim ends up with.
     *
     * Only ROLE_ ones: Spring Security 7 also adds FACTOR_BEARER, which records
     * how the caller authenticated (for multi-factor rules). It is not a role
     * and no rule here checks it.
     */
    private static Set<String> rolesFor(String role) {
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "HS256")
                .subject("9")
                .claim("role", role)
                .build();

        return new JwtConfig().jwtAuthenticationConverter().convert(jwt)
                .getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .filter(authority -> authority.startsWith("ROLE_"))
                .collect(Collectors.toSet());
    }

    @Test
    void aSupervisorTokenGetsTheSupervisorRole() {
        assertEquals(Set.of("ROLE_SUPERVISOR"), rolesFor("SUPERVISOR"));
    }

    @Test
    void anEmployeeTokenGetsOnlyTheEmployeeRole() {
        assertEquals(Set.of("ROLE_EMPLOYEE"), rolesFor("EMPLOYEE"));
    }
}
