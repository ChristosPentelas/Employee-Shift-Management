package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.model.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;

/**
 * Issues the token a user receives after logging in.
 *
 * A JWT is signed, not encrypted: anyone can base64-decode it and read the
 * claims. So it carries only what the server needs to recognise the caller -
 * the user id and role - never the password, email or anything private.
 */
@Service
public class TokenService {

    public static final String ISSUER = "employee-shift-management";

    /** Read back by JwtConfig.jwtAuthenticationConverter; one name, so the two cannot drift apart. */
    public static final String ROLE_CLAIM = "role";

    private final JwtEncoder jwtEncoder;
    private final Duration lifetime;

    public TokenService(JwtEncoder jwtEncoder,
                        @Value("${app.jwt.expiration:8h}") Duration lifetime) {
        this.jwtEncoder = jwtEncoder;
        this.lifetime = lifetime;
    }

    public String issueToken(User user) {
        Instant now = Instant.now();

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .issuedAt(now)
                .expiresAt(now.plus(lifetime))
                // The id, not the email: a user can change their email through
                // PUT /users/{id}, but their id never changes.
                .subject(String.valueOf(user.getId()))
                .claim(ROLE_CLAIM, user.getRole())
                .build();

        // The encoder defaults to RS256 (key pair); our key is a shared secret,
        // so the algorithm has to be named explicitly.
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();

        return jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }
}
