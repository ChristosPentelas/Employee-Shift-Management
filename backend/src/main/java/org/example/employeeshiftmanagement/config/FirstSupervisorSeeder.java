package org.example.employeeshiftmanagement.config;

import org.example.employeeshiftmanagement.service.UserService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * Creates the company's first supervisor when the application starts.
 *
 * Spring calls run() once, after the application context is ready. The
 * settings come from application-local.properties (gitignored), so the initial
 * password never enters version control. When they are not set - in tests, or
 * on a fresh clone - the seeder only logs a warning and the app starts anyway.
 *
 * This class only reads configuration and reports; the decision whether to
 * create a supervisor lives in UserService.
 */
@Component
public class FirstSupervisorSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(FirstSupervisorSeeder.class);

    private final UserService userService;
    private final String name;
    private final String email;
    private final String password;

    // The ":" after each key is the default when the property is missing: an
    // empty string instead of a startup failure.
    public FirstSupervisorSeeder(UserService userService,
                                 @Value("${app.first-supervisor.name:}") String name,
                                 @Value("${app.first-supervisor.email:}") String email,
                                 @Value("${app.first-supervisor.password:}") String password) {
        this.userService = userService;
        this.name = name;
        this.email = email;
        this.password = password;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (name.isBlank() || email.isBlank() || password.isBlank()) {
            log.warn("No first supervisor configured (app.first-supervisor.*); skipping seeding");
            return;
        }

        // Never log the password.
        if (userService.createFirstSupervisorIfNone(name, email, password)) {
            log.info("Created the first supervisor: {}", email);
        } else {
            log.info("A supervisor already exists; first-supervisor settings ignored");
        }
    }
}
