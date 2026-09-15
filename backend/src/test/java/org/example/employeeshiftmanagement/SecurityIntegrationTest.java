package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.service.TokenService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

/**
 * Security checked over real HTTP, against a real server and a real database.
 *
 * The @WebMvcTest classes use MockMvc, which skips parts of a real request:
 * no real token is signed or verified, the role claim is never converted
 * (TestTokens sets authorities directly), and a failed request is never
 * forwarded to /error. All three matter for security, so this class runs the
 * whole path.
 *
 * It starts its own server on a random port. Its configuration differs from
 * the other @SpringBootTest classes (a web environment), so Spring cannot reuse
 * their context and a second MySQL container starts - that is the ~30 s cost.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class SecurityIntegrationTest {

    @Value("${local.server.port}")
    private int port;

    @Autowired
    private UserService userService;

    private RestClient client() {
        return RestClient.builder()
                .baseUrl("http://localhost:" + port + "/api/v1")
                .build();
    }

    /** The status code, without RestClient turning 4xx into an exception. */
    private HttpStatusCode getShifts(String token) {
        RestClient.RequestHeadersSpec<?> request = client().get().uri("/shifts");
        if (token != null) {
            request = request.header("Authorization", "Bearer " + token);
        }
        return request.exchange((req, response) -> response.getStatusCode());
    }

    private HttpStatusCode createAccount(String token, String email) {
        return client().post().uri("/users")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {"name":"Created","email":"%s","password":"secret123"}
                        """.formatted(email))
                .exchange((req, response) -> response.getStatusCode());
    }

    /** registerNewEmployee keeps a role that is already set, so this can create a supervisor too. */
    private User registeredUser(String email, String role) {
        User user = new User();
        user.setName("Integration User");
        user.setEmail(email);
        user.setPassword("secret123");
        user.setRole(role);
        return userService.registerNewEmployee(user);
    }

    /** Logs in through the real endpoint and returns the token it hands out. */
    private String login(String email) {
        Map<?, ?> response = client().post().uri("/users/login")
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {"email":"%s","password":"secret123"}
                        """.formatted(email))
                .retrieve()
                .body(Map.class);

        assertNotNull(response);
        String token = (String) response.get("token");
        assertNotNull(token, "login must return a token");
        return token;
    }

    @Test
    void aRequestWithoutATokenIsUnauthorized() {
        assertEquals(401, getShifts(null).value());
    }

    @Test
    void aSupervisorsLoginTokenOpensASupervisorEndpoint() {
        registeredUser("it-login@example.com", "SUPERVISOR");

        assertEquals(200, getShifts(login("it-login@example.com")).value());
    }

    @Test
    void anEmployeesLoginTokenIsForbiddenFromASupervisorEndpoint() {
        registeredUser("it-employee-shifts@example.com", null);

        // 403, not 401: the token is valid, the role is not enough.
        assertEquals(403, getShifts(login("it-employee-shifts@example.com")).value());
    }

    @Test
    void onlyASupervisorsRealTokenCanCreateAccounts() {
        registeredUser("it-employee@example.com", null);
        registeredUser("it-boss@example.com", "SUPERVISOR");

        assertEquals(403, createAccount(login("it-employee@example.com"), "it-by-employee@example.com").value());
        assertEquals(201, createAccount(login("it-boss@example.com"), "it-by-supervisor@example.com").value());
    }

    @Test
    void aTokenSignedWithADifferentKeyIsUnauthorized() {
        User user = registeredUser("it-forged@example.com", "SUPERVISOR");
        JwtConfig jwtConfig = new JwtConfig();
        String otherKey = Base64.getEncoder().encodeToString(new byte[32]);
        TokenService forger = new TokenService(
                jwtConfig.jwtEncoder(JwtConfig.signingKey(otherKey)), Duration.ofHours(8));

        assertEquals(401, getShifts(forger.issueToken(user)).value());
    }

    @Test
    void anExpiredTokenIsUnauthorized() {
        User user = registeredUser("it-expired@example.com", "SUPERVISOR");
        JwtEncoder encoder = new JwtConfig().jwtEncoder(JwtConfig.signingKey(TestProperties.JWT_SECRET));

        // The right key and the right claims, but issued 9 hours ago with the
        // normal 8-hour lifetime: it expired an hour ago. (Spring refuses to
        // encode a token whose expiry is before its issue time, so a negative
        // lifetime cannot be used. Spring also allows 60 seconds of clock
        // difference, so "just expired" would still pass.)
        Instant issuedAt = Instant.now().minus(Duration.ofHours(9));
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(TokenService.ISSUER)
                .issuedAt(issuedAt)
                .expiresAt(issuedAt.plus(Duration.ofHours(8)))
                .subject(String.valueOf(user.getId()))
                .claim(TokenService.ROLE_CLAIM, user.getRole())
                .build();
        String expiredToken = encoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();

        assertEquals(401, getShifts(expiredToken).value());
    }

    @Test
    void aRealTokenOpensOnlyItsOwnInbox() {
        User alice = registeredUser("it-alice@example.com", null);
        User bob = registeredUser("it-bob@example.com", null);
        String aliceToken = login("it-alice@example.com");

        HttpStatusCode own = client().get().uri("/messages/inbox/" + alice.getId())
                .header("Authorization", "Bearer " + aliceToken)
                .exchange((req, response) -> response.getStatusCode());
        HttpStatusCode someoneElses = client().get().uri("/messages/inbox/" + bob.getId())
                .header("Authorization", "Bearer " + aliceToken)
                .exchange((req, response) -> response.getStatusCode());

        // Proves the token's subject really is the user id that
        // "authentication.name" is compared with in @PreAuthorize.
        assertEquals(200, own.value());
        assertEquals(403, someoneElses.value());
    }

    @Test
    void invalidLoginInputIsBadRequestNotUnauthorized() {
        // Validation errors are forwarded to /error. If /error required a token,
        // this would come back as 401 and hide the real problem.
        HttpStatusCode status = client().post().uri("/users/login")
                .contentType(MediaType.APPLICATION_JSON)
                .body("""
                        {"email":"","password":"secret123"}
                        """)
                .exchange((req, response) -> response.getStatusCode());

        assertEquals(400, status.value());
    }
}
