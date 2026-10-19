package org.example.employeeshiftmanagement;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.PropertySource;

import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.assertFalse;

@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class EmployeeShiftManagementApplicationTests {

    @Autowired
    private ConfigurableEnvironment environment;

    @Test
    void contextLoads() {
    }

    /**
     * B13: a test's result must not depend on whose machine runs it.
     *
     * Can only fail where backend/application-local.properties exists; on a
     * machine without the file there is nothing to leak. The test does not
     * create one itself, because it would be writing next to a real one.
     */
    @Test
    void doesNotLoadTheDevelopersLocalSettings() {
        assertFalse(Arrays.asList(environment.getActiveProfiles()).contains("local"),
                "the 'local' profile is active in a test; is SPRING_PROFILES_ACTIVE set?");

        for (PropertySource<?> source : environment.getPropertySources()) {
            assertFalse(source.getName().contains("application-local.properties"),
                    "a test loaded " + source.getName());
        }
    }

}
