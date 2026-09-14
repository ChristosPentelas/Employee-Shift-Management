package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.junit.jupiter.api.Test;

import java.util.Base64;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

/** The app must refuse to start with a signing key that is missing or too weak. */
class JwtConfigTest {

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
}
