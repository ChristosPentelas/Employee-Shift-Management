package org.example.employeeshiftmanagement;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

/**
 * A clock that only moves when a test says so.
 *
 * Code that takes a Clock instead of calling Instant.now() can be tested for
 * "15 minutes later" without waiting 15 minutes: hand it this, then advance().
 */
final class TestClock extends Clock {

    private Instant now;

    TestClock(Instant start) {
        this.now = start;
    }

    void advance(Duration duration) {
        now = now.plus(duration);
    }

    @Override
    public Instant instant() {
        return now;
    }

    @Override
    public ZoneId getZone() {
        return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(ZoneId zone) {
        throw new UnsupportedOperationException("TestClock is always UTC");
    }
}
