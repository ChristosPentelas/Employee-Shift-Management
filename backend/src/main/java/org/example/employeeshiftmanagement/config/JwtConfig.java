package org.example.employeeshiftmanagement.config;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;

/**
 * The key that signs login tokens, and the objects that use it.
 *
 * HS256 means one shared secret both signs and verifies. That fits a single
 * server that issues and checks its own tokens. RS256 (a private/public key
 * pair) is what you need once other services must verify tokens without being
 * able to create them.
 *
 * Whoever knows the secret can forge a token for any user, so it lives in the
 * gitignored application-local.properties, never in git (see F4).
 */
@Configuration
public class JwtConfig {

    /** HS256 needs a key of at least 256 bits. */
    public static final int MIN_SECRET_BYTES = 32;

    @Bean
    public SecretKey jwtSigningKey(@Value("${app.jwt.secret:}") String base64Secret) {
        return signingKey(base64Secret);
    }

    @Bean
    public JwtEncoder jwtEncoder(SecretKey jwtSigningKey) {
        return new NimbusJwtEncoder(new ImmutableSecret<>(jwtSigningKey));
    }

    /** Not used by any request yet; F1 step 4 makes Spring Security check tokens with it. */
    @Bean
    public JwtDecoder jwtDecoder(SecretKey jwtSigningKey) {
        return NimbusJwtDecoder.withSecretKey(jwtSigningKey)
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
    }

    /**
     * Turns the configured Base64 text into a key, refusing anything unusable.
     *
     * Fails at startup on purpose (fail fast): a missing or weak signing key is
     * a security hole, not something to warn about and carry on.
     */
    public static SecretKey signingKey(String base64Secret) {
        if (base64Secret == null || base64Secret.isBlank()) {
            throw new IllegalStateException(
                    "app.jwt.secret is not set; see application-local.properties.example");
        }

        byte[] bytes;
        try {
            bytes = Base64.getDecoder().decode(base64Secret.trim());
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("app.jwt.secret must be Base64-encoded", e);
        }

        if (bytes.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("app.jwt.secret must decode to at least "
                    + MIN_SECRET_BYTES + " bytes, got " + bytes.length);
        }

        return new SecretKeySpec(bytes, "HmacSHA256");
    }
}
