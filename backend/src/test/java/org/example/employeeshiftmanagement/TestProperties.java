package org.example.employeeshiftmanagement;

/**
 * Settings every @SpringBootTest passes:
 * {@code @SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})}
 *
 * Tests do not see the developer's application-local.properties: it is read
 * only under the "local" profile, which tests never activate (B13, checked by
 * EmployeeShiftManagementApplicationTests). So the JWT secret has to come from
 * here - without it the context refuses to start.
 *
 * Using the same constants everywhere also keeps the test configuration
 * identical, which lets Spring reuse one context - and one MySQL container -
 * across test classes.
 */
final class TestProperties {

    /** Base64 of "test-only-jwt-secret-not-for-production!" (40 bytes). Never use outside tests. */
    static final String JWT_SECRET = "dGVzdC1vbmx5LWp3dC1zZWNyZXQtbm90LWZvci1wcm9kdWN0aW9uIQ==";

    static final String JWT_SECRET_PROPERTY = "app.jwt.secret=" + JWT_SECRET;

    /**
     * An empty email makes FirstSupervisorSeeder skip. A seeded supervisor is
     * created at startup - outside any test transaction, so never rolled back -
     * and every test that expects no supervisor would fail. Since B13 no local
     * file can supply one; this stays as a second guard, e.g. against
     * app.first-supervisor.* set as environment variables.
     */
    static final String NO_SUPERVISOR_SEEDING = "app.first-supervisor.email=";

    private TestProperties() {
    }
}
