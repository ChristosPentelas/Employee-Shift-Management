package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.exception.TooManyAttemptsException;
import org.example.employeeshiftmanagement.service.LoginAttemptService;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * The lockout rule on its own (B56): 5 failures in a row lock a key for
 * 15 minutes.
 *
 * A plain unit test, no Spring and no database: the service only needs a
 * clock, and a TestClock lets these tests jump 15 minutes ahead at once.
 *
 * startAttempt counts the attempt as a failure before the password is
 * checked, and succeeded() takes it back. So "a failed login" here is a
 * startAttempt that is not followed by succeeded().
 */
class LoginAttemptServiceTest {

    private static final String KEY = "user:1";

    private final TestClock clock = new TestClock(Instant.parse("2026-10-16T09:00:00Z"));
    private final LoginAttemptService attempts = new LoginAttemptService(clock);

    private void fail(String key, int times) {
        for (int i = 0; i < times; i++) {
            attempts.startAttempt(key);
        }
    }

    @Test
    void theLimitsAreFiveTriesAndFifteenMinutes() {
        // Pinned so a change to either number is a decision, not an accident.
        assertEquals(5, LoginAttemptService.MAX_FAILURES);
        assertEquals(Duration.ofMinutes(15), LoginAttemptService.LOCK_DURATION);
    }

    @Test
    void fiveFailedAttemptsAreAllAllowed() {
        // The 5th attempt still gets its answer; only the 6th is refused.
        assertDoesNotThrow(() -> fail(KEY, 5));
    }

    @Test
    void theSixthAttemptIsRefusedForTheWholeLock() {
        fail(KEY, 5);

        TooManyAttemptsException refused =
                assertThrows(TooManyAttemptsException.class, () -> attempts.startAttempt(KEY));

        assertEquals(Duration.ofMinutes(15), refused.getRetryAfter());
    }

    @Test
    void retryAfterIsWhatIsLeftOfTheLock() {
        fail(KEY, 5);
        clock.advance(Duration.ofMinutes(10));

        TooManyAttemptsException refused =
                assertThrows(TooManyAttemptsException.class, () -> attempts.startAttempt(KEY));

        assertEquals(Duration.ofMinutes(5), refused.getRetryAfter());
    }

    @Test
    void aRefusedAttemptDoesNotMakeTheLockLonger() {
        // Otherwise a script that keeps knocking would keep a colleague locked
        // out for as long as it runs, not 15 minutes.
        fail(KEY, 5);
        clock.advance(Duration.ofMinutes(10));
        assertThrows(TooManyAttemptsException.class, () -> attempts.startAttempt(KEY));

        clock.advance(Duration.ofMinutes(5));

        assertDoesNotThrow(() -> attempts.startAttempt(KEY));
    }

    @Test
    void theAccountIsStillLockedOneSecondBeforeTheEnd() {
        fail(KEY, 5);
        clock.advance(Duration.ofMinutes(15).minusSeconds(1));

        assertThrows(TooManyAttemptsException.class, () -> attempts.startAttempt(KEY));
    }

    @Test
    void afterTheLockTheCountStartsAgainFromZero() {
        fail(KEY, 5);
        clock.advance(Duration.ofMinutes(15));

        // Five fresh tries, then locked again - not locked again on the first
        // wrong try because the old count was kept.
        assertDoesNotThrow(() -> fail(KEY, 5));
        assertThrows(TooManyAttemptsException.class, () -> attempts.startAttempt(KEY));
    }

    @Test
    void aSuccessClearsTheCount() {
        fail(KEY, 4);
        attempts.succeeded(KEY);

        // Without the reset, the 5th of these would be the 9th in a row.
        assertDoesNotThrow(() -> fail(KEY, 5));
    }

    @Test
    void theRightPasswordOnTheFifthTryLeavesNoLockBehind() {
        // The 5th startAttempt sets the lock before the password is checked;
        // when that password turns out right, succeeded() must undo it.
        fail(KEY, 5);
        attempts.succeeded(KEY);

        assertDoesNotThrow(() -> attempts.startAttempt(KEY));
    }

    @Test
    void anOldFailureIsForgotten() {
        // 4 typos in the morning and 1 in the afternoon are not "5 in a row".
        fail(KEY, 4);
        clock.advance(Duration.ofMinutes(15));

        assertDoesNotThrow(() -> fail(KEY, 5));
    }

    @Test
    void failuresCloseTogetherKeepCounting() {
        // Each failure is less than 15 minutes after the one before, so all
        // five count, even though the first and the last are 20 minutes apart.
        for (int i = 0; i < 5; i++) {
            attempts.startAttempt(KEY);
            clock.advance(Duration.ofMinutes(5));
        }
        // 5 minutes after the 5th failure: 10 minutes of the lock are left.

        assertThrows(TooManyAttemptsException.class, () -> attempts.startAttempt(KEY));
    }

    @Test
    void oneLockedKeyDoesNotLockAnother() {
        fail(KEY, 5);

        assertDoesNotThrow(() -> attempts.startAttempt("user:2"));
    }
}
