package org.example.employeeshiftmanagement.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

/**
 * The clock every class that needs "now" asks for (B56).
 *
 * A class that calls Instant.now(clock) instead of Instant.now() can be tested
 * for "15 minutes later" by handing it a clock the test moves forward, rather
 * than by waiting 15 minutes (see TestClock).
 *
 * UTC, so a stored Instant never depends on the server's time zone.
 */
@Configuration
public class TimeConfig {

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }
}
