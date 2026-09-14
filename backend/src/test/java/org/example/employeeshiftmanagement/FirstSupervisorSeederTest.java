package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.FirstSupervisorSeeder;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * Plain unit test: no Spring context and no Docker. The seeder takes its
 * settings through the constructor, so the test can build it with "new" and
 * hand it a mock UserService.
 */
class FirstSupervisorSeederTest {

    private final UserService userService = mock(UserService.class);

    @Test
    void doesNothingWhenNoSupervisorIsConfigured() {
        new FirstSupervisorSeeder(userService, "", "", "").run(null);

        verify(userService, never()).createFirstSupervisorIfNone(any(), any(), any());
    }

    @Test
    void doesNothingWhenOnlySomeSettingsArePresent() {
        new FirstSupervisorSeeder(userService, "Boss", "boss@example.com", "").run(null);

        verify(userService, never()).createFirstSupervisorIfNone(any(), any(), any());
    }

    @Test
    void passesTheConfiguredValuesToTheService() {
        new FirstSupervisorSeeder(userService, "Boss", "boss@example.com", "secret123").run(null);

        verify(userService).createFirstSupervisorIfNone("Boss", "boss@example.com", "secret123");
    }
}
