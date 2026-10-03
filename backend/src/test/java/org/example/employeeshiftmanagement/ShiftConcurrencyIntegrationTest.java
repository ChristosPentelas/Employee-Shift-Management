package org.example.employeeshiftmanagement;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.model.Shift;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.ShiftService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Sort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

/**
 * Two shift writes for the same employee at the same moment (B30).
 *
 * <p>Each test replays the race step by step instead of hoping two threads
 * collide by chance:
 * <ol>
 *   <li>The "first request" runs in its own thread: it locks the employee's
 *       row, saves a 09:00-17:00 shift, and then holds its transaction open
 *       without committing.</li>
 *   <li>The "second request" calls ShiftService with a shift that overlaps
 *       it, in another thread. It must get stuck at the employee's lock - a
 *       {@code SELECT ... FOR UPDATE} on users - before its overlap check.
 *       The test asks MySQL which statement it is stuck in, rather than
 *       guessing with a sleep.</li>
 *   <li>The first request commits. The second gets the lock and must now see
 *       the 09:00-17:00 shift and answer ConflictException.</li>
 * </ol>
 *
 * <p>Without the lock, the second request still gets stuck - but later, at
 * its INSERT or UPDATE of shifts: saving a shift checks the foreign key to
 * users, and that check waits for the first request's lock too. By then its
 * overlap check has already passed, which is the bug.
 *
 * <p>For updateShift there is a second way to fail, which its test exists
 * for: even with the lock, under MySQL's default REPEATABLE READ the overlap
 * check reads the snapshot taken by the method's first plain SELECT (loading
 * the shift), before the wait - so it still misses the committed shift.
 * READ_COMMITTED on the service method is what makes it look again.
 *
 * <p>The first request locks with plain JPA ({@code EntityManager.find} with
 * PESSIMISTIC_WRITE) rather than through UserService, so this test describes
 * the behaviour, not which method the service uses to get it.
 *
 * <p>Not {@code @Transactional}, for two reasons: the two requests must be two
 * real transactions on two connections, and a service method that joins a
 * test transaction ignores its own isolation level. So the employee and their
 * shifts are deleted by hand afterwards.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
class ShiftConcurrencyIntegrationTest {

    private static final LocalDate DAY = LocalDate.of(2026, 10, 5);

    /** How long the test waits for the second request to get stuck before deciding it never will. */
    private static final Duration PATIENCE = Duration.ofSeconds(10);

    @Autowired private ShiftService shiftService;
    @Autowired private UserService userService;
    @Autowired private UserRepository userRepository;
    @Autowired private ShiftRepository shiftRepository;
    @Autowired private EntityManager entityManager;
    @Autowired private PlatformTransactionManager transactionManager;
    @Autowired private JdbcTemplate jdbcTemplate;

    private final ExecutorService threads = Executors.newFixedThreadPool(2);

    /** Counted down once the first request holds the lock and has saved its shift. */
    private final CountDownLatch firstRequestHoldsTheLock = new CountDownLatch(1);

    /** Counted down to let the first request commit. */
    private final CountDownLatch commitTheFirstRequest = new CountDownLatch(1);

    private User employee;

    @BeforeEach
    void anEmployee() {
        employee = new User();
        employee.setName("Concurrent");
        employee.setEmail("concurrent@tx-test.example");
        employee.setPassword("secret123");
        employee.setRole("EMPLOYEE");
        employee = userRepository.save(employee);
    }

    @AfterEach
    void releaseTheLockAndCleanUp() throws InterruptedException {
        // A failed assertion must not leave the first request holding the
        // lock: deleteUser below would then wait for it.
        commitTheFirstRequest.countDown();
        threads.shutdown();
        assertTrue(threads.awaitTermination(PATIENCE.toSeconds(), TimeUnit.SECONDS),
                "A request thread is still running");
        userService.deleteUser(employee.getId());
    }

    @Test
    void anOverlappingShiftCreatedAtTheSameMomentIsRefused() throws Exception {
        Future<?> first = startTheFirstRequest();

        Future<Shift> second = threads.submit(
                () -> shiftService.createShift(employee.getId(), shift(12, 20)));

        assertStuckAtTheEmployeesLock(second, "createShift");
        commitTheFirstRequest.countDown();
        first.get();

        ExecutionException e = assertThrows(ExecutionException.class, second::get,
                "createShift saved a shift that overlaps one committed while it waited");
        assertInstanceOf(ConflictException.class, e.getCause());
        assertEquals(List.of("09:00-17:00"), employeesShifts());
    }

    @Test
    void aShiftMovedOntoOneCreatedAtTheSameMomentIsRefused() throws Exception {
        Shift early = shiftRepository.save(withEmployee(shift(6, 8)));
        Future<?> first = startTheFirstRequest();

        Future<Shift> second = threads.submit(
                () -> shiftService.updateShift(early.getId(), shift(12, 20)));

        assertStuckAtTheEmployeesLock(second, "updateShift");
        commitTheFirstRequest.countDown();
        first.get();

        ExecutionException e = assertThrows(ExecutionException.class, second::get,
                "updateShift waited for the lock, but then moved a shift onto one committed while it "
                        + "waited: its overlap check read a snapshot taken before the wait "
                        + "(REPEATABLE READ instead of READ_COMMITTED?)");
        assertInstanceOf(ConflictException.class, e.getCause());
        assertEquals(List.of("06:00-08:00", "09:00-17:00"), employeesShifts());
    }

    /**
     * Step 1: lock the employee, save 09:00-17:00, and keep the transaction
     * open until commitTheFirstRequest is counted down. It holds on longer
     * than the test waits in step 2, so it can never commit early by itself.
     */
    private Future<?> startTheFirstRequest() throws InterruptedException {
        Future<?> first = threads.submit(() -> new TransactionTemplate(transactionManager).executeWithoutResult(tx -> {
            User locked = entityManager.find(User.class, employee.getId(), LockModeType.PESSIMISTIC_WRITE);
            Shift shift = shift(9, 17);
            shift.setUser(locked);
            shiftRepository.save(shift);
            firstRequestHoldsTheLock.countDown();
            try {
                // Bounded, so a broken test cannot hang the build.
                commitTheFirstRequest.await(3 * PATIENCE.toSeconds(), TimeUnit.SECONDS);
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
            }
        }));
        assertTrue(firstRequestHoldsTheLock.await(PATIENCE.toSeconds(), TimeUnit.SECONDS),
                "The first request never got the lock");
        return first;
    }

    /**
     * Step 2: the second request must be stuck in a statement, and that
     * statement must be the lock on users. Being stuck also proves it has
     * already run everything before the lock - including, in updateShift, the
     * SELECT that could take a stale snapshot.
     */
    private void assertStuckAtTheEmployeesLock(Future<?> second, String method) throws InterruptedException {
        Instant giveUp = Instant.now().plus(PATIENCE);
        Optional<String> stuck = Optional.empty();
        while (!second.isDone() && stuck.isEmpty() && Instant.now().isBefore(giveUp)) {
            Thread.sleep(50);
            stuck = statementStuckForASecond();
        }

        assertFalse(second.isDone(),
                method + " finished while another transaction held the employee's lock: it never waited for it");
        String statement = stuck.orElseGet(() -> fail(method + " neither finished nor got stuck in a statement"));
        assertTrue(statement.contains("from users") && statement.contains("for update"),
                method + " is stuck at\n    " + statement + "\nnot at the employee's lock, so its overlap "
                        + "check ran before the first request committed");
    }

    /**
     * The statement another connection has been running for a second or more:
     * nothing in this test takes that long unless it is waiting for a lock.
     *
     * Every connection here logs in as the same database user, and MySQL
     * shows a user its own connections without any extra privilege. The
     * first request is not in this list while it holds the lock: between
     * statements a connection is "Sleep", not "Query".
     */
    private Optional<String> statementStuckForASecond() {
        return jdbcTemplate.queryForList("""
                        SELECT info FROM information_schema.PROCESSLIST
                        WHERE command = 'Query' AND time >= 1 AND id <> CONNECTION_ID()""", String.class)
                .stream()
                .map(String::toLowerCase)
                .findFirst();
    }

    /** The employee's shifts around DAY, as "HH:mm-HH:mm", earliest first. */
    private List<String> employeesShifts() {
        return shiftRepository.findByUserIdAndDateBetween(employee.getId(), DAY.minusDays(1), DAY.plusDays(1),
                        Sort.by("startTime"))
                .stream()
                .map(shift -> shift.getStartTime() + "-" + shift.getEndTime())
                .toList();
    }

    private static Shift shift(int startHour, int endHour) {
        Shift shift = new Shift();
        shift.setDate(DAY);
        shift.setStartTime(LocalTime.of(startHour, 0));
        shift.setEndTime(LocalTime.of(endHour, 0));
        shift.setPosition("Cashier");
        return shift;
    }

    private Shift withEmployee(Shift shift) {
        shift.setUser(employee);
        return shift;
    }
}
