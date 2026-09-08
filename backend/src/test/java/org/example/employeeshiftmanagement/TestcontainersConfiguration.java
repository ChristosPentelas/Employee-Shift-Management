package org.example.employeeshiftmanagement;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.mysql.MySQLContainer;

/**
 * Gives the integration tests their own throwaway MySQL, so they no longer
 * depend on a MySQL installed and running on the developer's machine.
 *
 * <p><b>Docker must be running.</b> If it is not, every test fails while the
 * Spring context starts, with:
 * <pre>
 *   Could not find a valid Docker environment
 * </pre>
 * on Windows caused by:
 * <pre>
 *   open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified
 * </pre>
 * That is not a broken test — it means Docker Desktop is stopped. There is
 * deliberately no "skip the tests when Docker is missing" switch: a suite that
 * quietly skips itself reports green while proving nothing.
 *
 * <p>Why the container is a {@code @Bean} rather than a static
 * {@code @Container} field: as a bean its lifetime is tied to the Spring
 * ApplicationContext, and Spring caches and reuses that context across test
 * classes with identical configuration. One context therefore means one
 * container for the whole suite. A static {@code @Container} field is started
 * and stopped by JUnit per test class (and a non-static one per test
 * <i>method</i>), which is the classic way to accidentally start many.
 *
 * <p>{@code @ServiceConnection} publishes a {@code JdbcConnectionDetails} bean
 * built from the running container. Boot's datasource auto-configuration
 * prefers that bean over {@code spring.datasource.*}, so the localhost URL in
 * application.properties is not overridden — it is simply never consulted.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

    // Pinned to the exact production patch version. A floating tag like
    // "mysql:8.0" is re-pointed at new releases, which can turn the build red
    // with no commit to blame.
    @Bean
    @ServiceConnection
    MySQLContainer mysqlContainer() {
        return new MySQLContainer("mysql:8.0.44");
    }
}
