package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.service.TokenService;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtException;

import javax.crypto.SecretKey;
import java.time.Duration;
import java.util.Base64;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Plain unit test: builds the real encoder and decoder by hand, without
 * Spring, and checks a token round-trips through the same key.
 */
class TokenServiceTest {

    private final JwtConfig jwtConfig = new JwtConfig();
    private final SecretKey key = JwtConfig.signingKey(TestProperties.JWT_SECRET);
    private final TokenService tokenService =
            new TokenService(jwtConfig.jwtEncoder(key), Duration.ofHours(8));

    @Test
    void theTokenVerifiesWithTheSameKeyAndCarriesTheUserIdAndRole() {
        String token = tokenService.issueToken(TestUsers.supervisor());

        Jwt jwt = jwtConfig.jwtDecoder(key).decode(token);

        assertEquals("9", jwt.getSubject());
        assertEquals("SUPERVISOR", jwt.getClaimAsString("role"));
        assertEquals(TokenService.ISSUER, jwt.getClaimAsString("iss"));
    }

    @Test
    void theTokenExpiresAfterTheConfiguredLifetime() {
        Jwt jwt = jwtConfig.jwtDecoder(key).decode(tokenService.issueToken(TestUsers.employee()));

        assertEquals(Duration.ofHours(8), Duration.between(jwt.getIssuedAt(), jwt.getExpiresAt()));
    }

    @Test
    void theTokenCarriesNothingPrivate() {
        Jwt jwt = jwtConfig.jwtDecoder(key).decode(tokenService.issueToken(TestUsers.employee()));

        // Anyone holding a token can read these, so the list is pinned exactly:
        // adding "email" or "password" here must be a deliberate, visible change.
        assertEquals(Set.of("iss", "iat", "exp", "sub", "role"), jwt.getClaims().keySet());
    }

    @Test
    void aTokenSignedWithADifferentKeyIsRejected() {
        String token = tokenService.issueToken(TestUsers.employee());
        SecretKey otherKey = JwtConfig.signingKey(Base64.getEncoder().encodeToString(new byte[32]));

        assertThrows(JwtException.class, () -> jwtConfig.jwtDecoder(otherKey).decode(token));
    }
}
