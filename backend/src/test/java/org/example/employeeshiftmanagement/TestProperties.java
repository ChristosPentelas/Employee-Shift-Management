package org.example.employeeshiftmanagement;

/**
 * Settings every @SpringBootTest passes:
 * {@code @SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})}
 *
 * Tests DO see the developer's application-local.properties:
 * application.properties imports it from "./", and Maven runs the tests from
 * backend/. Properties given to @SpringBootTest win over that file, so these
 * are what keep a test's result independent of one person's local settings
 * (see B13).
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
     * An empty email makes FirstSupervisorSeeder skip. Without it, a supervisor
     * from someone's local file is created at startup - outside any test
     * transaction, so never rolled back - and every test that expects no
     * supervisor fails on that machine only.
     */
    static final String NO_SUPERVISOR_SEEDING = "app.first-supervisor.email=";

    private TestProperties() {
    }
}
