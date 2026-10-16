package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.TooManyAttemptsException;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * Locks a key for LOCK_DURATION after MAX_FAILURES failed attempts in a row
 * (B56), so a script cannot try passwords as fast as the server answers.
 *
 * A key is whatever the caller counts by - for a login, the user (see
 * UserService.authenticate). Failures count "in a row" while each comes less
 * than LOCK_DURATION after the one before; a longer gap starts again from
 * zero. The lock is short rather than permanent, because anyone who knows a
 * colleague's email can lock them out on purpose.
 *
 * In memory: the counts are lost on restart and not shared between two
 * servers. Enough for one server; several would need a shared store.
 */
@Service
public class LoginAttemptService {

    public static final int MAX_FAILURES = 5;
    public static final Duration LOCK_DURATION = Duration.ofMinutes(15);

    /** lockedUntil is null while the key is not locked. */
    private record Failures(int count, Instant lastFailure, Instant lockedUntil) {
    }

    private final Clock clock;

    /**
     * A plain HashMap is not safe to share between threads. It is safe here
     * only because every method that touches it is synchronized - a method
     * added later that reads it without synchronized would break that.
     */
    private final Map<String, Failures> failures = new HashMap<>();

    public LoginAttemptService(Clock clock) {
        this.clock = clock;
    }

    /**
     * Call before checking the password. Throws TooManyAttemptsException if the
     * key is locked; otherwise counts this attempt as a failure until
     * succeeded() takes it back.
     *
     * Counting first is what makes the limit hold. "Check the lock, check the
     * password, then count the failure" lets 200 requests sent at once all pass
     * the check during the ~100 ms BCrypt takes - 200 guesses, not 5 (a
     * check-then-act race). synchronized makes check and count one step;
     * BCrypt runs outside it, so other logins do not wait for it.
     */
    public synchronized void startAttempt(String key) {
        Instant now = Instant.now(clock);
        Failures current = failures.get(key);

        // Locked: refuse, and store nothing. A refused attempt neither counts
        // nor extends the lock, or a script that keeps knocking would keep the
        // account locked for as long as it runs.
        if (current != null && current.lockedUntil() != null && now.isBefore(current.lockedUntil())) {
            throw new TooManyAttemptsException(Duration.between(now, current.lockedUntil()));
        }

        // The last failure was LOCK_DURATION ago or more: start from zero. This
        // also clears an expired lock, which ends exactly LOCK_DURATION after
        // the failure that set it.
        if (current != null && !current.lastFailure().plus(LOCK_DURATION).isAfter(now)) {
            current = null;
        }

        int count = (current == null ? 0 : current.count()) + 1;
        Instant lockedUntil = count >= MAX_FAILURES ? now.plus(LOCK_DURATION) : null;
        // A record cannot be changed, so each attempt stores a new one.
        failures.put(key, new Failures(count, now, lockedUntil));
    }

    /**
     * The password was right: forget the key's failures, including the one
     * startAttempt counted for this attempt and any lock it set.
     */
    public synchronized void succeeded(String key) {
        failures.remove(key);
    }
}
