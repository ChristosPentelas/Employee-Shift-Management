package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.exception.ConflictException;
import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.exception.TooManyAttemptsException;
import org.example.employeeshiftmanagement.exception.WrongPasswordException;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
public class UserServiceTest {

    @Autowired
    private UserService userService;

    @Test
    void testRegisterAndFindUser() {

        User user = new User();
        user.setName("Test User");
        user.setEmail("test@example.com");
        user.setPassword("123456");

        User savedUser = userService.registerUser(user, "EMPLOYEE");
        assertNotNull(savedUser.getId(), "Το Id δεν πρέπει να είναι null μετά την αποθήκευση");

        User found = userService.findUserById(savedUser.getId());
        assertEquals("Test User", found.getName());

        List<User> users = userService.findAllUsers(PageRequest.of(0, 20)).getContent();
        assertTrue(users.size() > 0);

        assertEquals("EMPLOYEE", savedUser.getRole(), "Θα έπρεπε να έχει τον ρόλο που δόθηκε, EMPLOYEE");
        assertEquals("test@example.com", savedUser.getEmail());
    }

    @Test
    void registerUserUsesTheRoleItIsGivenNotTheOneTheUserCarries() {
        // B11: the old registerNewEmployee kept a role already set on the
        // user, so a SUPERVISOR here came out as a supervisor.
        User user = new User();
        user.setName("Would-be Boss");
        user.setEmail("would-be-boss@example.com");
        user.setPassword("secret123");
        user.setRole("SUPERVISOR");

        User saved = userService.registerUser(user, "EMPLOYEE");

        assertEquals("EMPLOYEE", saved.getRole());
        assertEquals("EMPLOYEE",
                userService.findUserByEmail("would-be-boss@example.com").orElseThrow().getRole());
    }

    @Test
    void testUpdateUser() {
        User user = new User();
        user.setName("Test User");
        user.setEmail("initial@example.com");
        user.setPassword("123456");
        User savedUser = userService.registerUser(user, "EMPLOYEE");

        //Update
        User details = new User();
        details.setName("Updated Name");
        details.setEmail("updated@example.com");
        details.setPhoneNumber("1234567890");

        User updatedUser = userService.updateUser(savedUser.getId(), details);

        assertEquals("Updated Name", updatedUser.getName());
        assertEquals("updated@example.com", updatedUser.getEmail());
        assertEquals("1234567890", updatedUser.getPhoneNumber());
    }

    @Test
    void testDeleteUser() {

        User user = new User();
        user.setName("Test User");
        user.setEmail("delete@example.com");
        user.setPassword("123456");
        User savedUser = userService.registerUser(user, "EMPLOYEE");

        assertDoesNotThrow(() -> userService.deleteUser(savedUser.getId()));

        //Verify deletion
        assertThrows(ResourceNotFoundException.class,
                () -> userService.findUserById(savedUser.getId()));
    }

    @Test
    void testRegisterUserWithExistingEmail() {
        User user1 = new User();
        user1.setName("Test User1");
        user1.setEmail("same@email.com");
        user1.setPassword("123456");
        userService.registerUser(user1, "EMPLOYEE");

        User user2 = new User();
        user2.setName("Test User2");
        user2.setEmail("same@email.com");
        user2.setPassword("123456");

        // 409, not 400 (B20): the request is well formed, the email is taken.
        assertThrows(ConflictException.class, () -> {
            userService.registerUser(user2, "EMPLOYEE");
        });
    }

    @Test
    void testFindUserByEmail() {

        User user1 = new User();
        user1.setName("Test User1");
        user1.setEmail("findme@example.com");
        user1.setPassword("123456");
        userService.registerUser(user1, "EMPLOYEE");

        Optional<User> found = userService.findUserByEmail(user1.getEmail());

        assertTrue(found.isPresent());
        assertEquals("Test User1", found.get().getName());

        // An unknown email is an expected outcome, so it comes back empty
        // rather than throwing.
        assertTrue(userService.findUserByEmail("false@example.com").isEmpty());
    }

    @Test
    void testUpdateUserWithExistingEmail() {
        User userA = new User();
        userA.setName("User A");
        userA.setEmail("userA@example.com");
        userA.setPassword("password");
        userService.registerUser(userA, "EMPLOYEE");

        User userB = new User();
        userB.setName("User B");
        userB.setEmail("userB@example.com");
        userB.setPassword("password");
        User savedB = userService.registerUser(userB, "EMPLOYEE");

        User updateDetails = new User();
        updateDetails.setName("Updated User B");
        updateDetails.setEmail("userA@example.com");

        assertThrows(ConflictException.class, () -> {
            userService.updateUser(savedB.getId(), updateDetails);
        });
    }

    private User registerLoginUser() {
        User user = new User();
        user.setName("Login User");
        user.setEmail("login@example.com");
        user.setPassword("secret123");
        return userService.registerUser(user, "EMPLOYEE");
    }

    @Test
    void authenticateReturnsTheUserForTheRightPassword() {
        User saved = registerLoginUser();

        Optional<User> result = userService.authenticate("login@example.com", "secret123");

        assertTrue(result.isPresent());
        assertEquals(saved.getId(), result.get().getId());
    }

    @Test
    void authenticateIsEmptyForAWrongPassword() {
        registerLoginUser();

        assertTrue(userService.authenticate("login@example.com", "wrong").isEmpty());
    }

    @Test
    void authenticateIsEmptyForAnUnknownEmail() {
        registerLoginUser();

        assertTrue(userService.authenticate("nobody@example.com", "secret123").isEmpty());
    }

    // --- limiting password guesses (B56) ---
    // The lockout rule itself (5 tries, 15 minutes, expiry) is checked in
    // LoginAttemptServiceTest. These check how authenticate uses it.
    //
    // The counters live in a Spring bean, so they are NOT rolled back with the
    // test transaction, and Spring reuses this context for other test classes.
    // Each test therefore uses an email no other test uses.

    private User registerWithPassword(String email) {
        User user = new User();
        user.setName("Lockout User");
        user.setEmail(email);
        user.setPassword("secret123");
        return userService.registerUser(user, "EMPLOYEE");
    }

    @Test
    void emailLookupIgnoresCaseAndAccents() {
        // Not new behaviour: this pins the reason the lockout counts per user,
        // not per typed email. The tables use utf8mb4_0900_ai_ci ("accent and
        // case insensitive"), so every spelling below logs in as the same
        // user, and a counter keyed on the typed text would give each
        // spelling its own 5 tries.
        registerWithPassword("lookup@example.com");

        assertTrue(userService.findUserByEmail("LOOKUP@example.com").isPresent());
        assertTrue(userService.findUserByEmail("Lookup@Example.COM").isPresent());
        assertTrue(userService.findUserByEmail("lööküp@example.com").isPresent());
    }

    @Test
    void fiveWrongPasswordsLockTheAccountEvenForTheRightPassword() {
        registerWithPassword("lock@example.com");
        for (int i = 0; i < 5; i++) {
            assertTrue(userService.authenticate("lock@example.com", "wrong").isEmpty(),
                    "attempt " + (i + 1) + " of 5 must still get an answer");
        }

        // If the right password still worked here, the lock would tell a
        // script "that was it" - it could keep guessing and only stop when
        // the answer changes.
        assertThrows(TooManyAttemptsException.class,
                () -> userService.authenticate("lock@example.com", "secret123"));
    }

    @Test
    void theRightPasswordResetsTheCount() {
        registerWithPassword("reset@example.com");
        for (int i = 0; i < 4; i++) {
            userService.authenticate("reset@example.com", "wrong");
        }
        assertTrue(userService.authenticate("reset@example.com", "secret123").isPresent());

        for (int i = 0; i < 4; i++) {
            userService.authenticate("reset@example.com", "wrong");
        }

        // 9 wrong in total, but never 5 in a row.
        assertTrue(userService.authenticate("reset@example.com", "secret123").isPresent());
    }

    @Test
    void anUnknownEmailIsLockedLikeAKnownOne() {
        // If only real accounts were locked, "the 6th try answers 429" would
        // mean "this email is registered" - the leak the dummy hash in
        // authenticate exists to prevent.
        for (int i = 0; i < 5; i++) {
            assertTrue(userService.authenticate("ghost@example.com", "wrong").isEmpty());
        }

        assertThrows(TooManyAttemptsException.class,
                () -> userService.authenticate("ghost@example.com", "wrong"));
    }

    @Test
    void everySpellingOfAKnownEmailCountsTowardsOneLock() {
        registerWithPassword("spelling@example.com");
        userService.authenticate("SPELLING@example.com", "wrong");
        userService.authenticate("Spelling@Example.com", "wrong");
        userService.authenticate("spëlling@example.com", "wrong");
        userService.authenticate("spelling@EXAMPLE.COM", "wrong");
        userService.authenticate("spélling@example.com", "wrong");

        assertThrows(TooManyAttemptsException.class,
                () -> userService.authenticate("spelling@example.com", "secret123"));
    }

    @Test
    void anUnknownEmailInAnotherCaseCountsTowardsOneLock() {
        userService.authenticate("PHANTOM@example.com", "wrong");
        userService.authenticate("Phantom@example.com", "wrong");
        userService.authenticate("phantom@EXAMPLE.com", "wrong");
        userService.authenticate("phantom@example.com", "wrong");
        userService.authenticate("pHaNtOm@example.com", "wrong");

        assertThrows(TooManyAttemptsException.class,
                () -> userService.authenticate("phantom@example.com", "wrong"));
    }

    @Test
    void lockingOneAccountLeavesTheOthersAlone() {
        registerWithPassword("locked-out@example.com");
        registerWithPassword("bystander@example.com");
        for (int i = 0; i < 5; i++) {
            userService.authenticate("locked-out@example.com", "wrong");
        }

        assertTrue(userService.authenticate("bystander@example.com", "secret123").isPresent());
    }

    @Test
    void registerStoresAHashNotThePlaintextPassword() {
        User saved = registerLoginUser();

        assertNotEquals("secret123", saved.getPassword(),
                "The plaintext password must never be stored (F2)");
        assertTrue(saved.getPassword().startsWith("$2"),
                "Expected a BCrypt hash, got: " + saved.getPassword());
    }

    @Test
    void theSamePasswordGetsADifferentHashEachTime() {
        User first = registerLoginUser();

        User second = new User();
        second.setName("Second User");
        second.setEmail("second@example.com");
        second.setPassword("secret123");
        User savedSecond = userService.registerUser(second, "EMPLOYEE");

        // Different salts, so identical passwords cannot be spotted by comparing
        // stored values.
        assertNotEquals(first.getPassword(), savedSecond.getPassword());
    }

    @Test
    void createsTheFirstSupervisorWhenNoneExists() {
        boolean created = userService.createFirstSupervisorIfNone("Boss", "boss@example.com", "secret123");

        assertTrue(created);
        User boss = userService.findUserByEmail("boss@example.com").orElseThrow();
        assertEquals("SUPERVISOR", boss.getRole());
        assertTrue(boss.getPassword().startsWith("$2"),
                "The seeded password must be hashed like any other (F2)");
    }

    @Test
    void doesNotCreateASecondSupervisor() {
        userService.createFirstSupervisorIfNone("Boss", "boss@example.com", "secret123");

        boolean createdAgain = userService.createFirstSupervisorIfNone("Other", "other@example.com", "secret123");

        assertFalse(createdAgain);
        assertTrue(userService.findUserByEmail("other@example.com").isEmpty());
    }

    @Test
    void registerRejectsAPasswordOverTheByteLimit() {
        // 40 Greek characters = 80 bytes in UTF-8, over BCrypt's 72-byte limit
        // while being only 40 characters long.
        String longPassword = "κ".repeat(40);

        User user = new User();
        user.setName("Long Password");
        user.setEmail("long@example.com");
        user.setPassword(longPassword);

        assertThrows(IllegalStateException.class, () -> userService.registerUser(user, "EMPLOYEE"));
    }

    @Test
    void theStaffListIsByNameWhateverSortTheClientSends() {
        User zoe = new User();
        zoe.setName("Zoe Paging");
        zoe.setEmail("zoe-paging@example.com");
        zoe.setPassword("aaaaaa");
        User adam = new User();
        adam.setName("Adam Paging");
        adam.setEmail("adam-paging@example.com");
        adam.setPassword("zzzzzz");
        userService.registerUser(zoe, "EMPLOYEE");
        userService.registerUser(adam, "EMPLOYEE");

        // ?sort=password would let a caller learn about the password hashes
        // from the order alone; the service must replace it with its own.
        List<String> names = userService.findAllUsers(PageRequest.of(0, 100, Sort.by("password")))
                .getContent().stream().map(User::getName)
                .filter(name -> name.endsWith("Paging")).toList();

        assertEquals(List.of("Adam Paging", "Zoe Paging"), names);
    }

    // --- changing your own password (B8) ---
    // Checked through authenticate, the way a real login checks it: comparing
    // hashes directly would not work, since every hash gets a new salt.

    @Test
    void afterAPasswordChangeOnlyTheNewPasswordLogsIn() {
        User saved = registerLoginUser();

        userService.changePassword(saved.getId(), "secret123", "newSecret456");

        assertTrue(userService.authenticate("login@example.com", "newSecret456").isPresent(),
                "the new password must log in");
        assertTrue(userService.authenticate("login@example.com", "secret123").isEmpty(),
                "the old password must stop working");
    }

    @Test
    void aChangedPasswordIsStoredAsAHash() {
        User saved = registerLoginUser();

        userService.changePassword(saved.getId(), "secret123", "newSecret456");

        String stored = userService.findUserById(saved.getId()).getPassword();
        assertNotEquals("newSecret456", stored, "The plaintext password must never be stored (F2)");
        assertTrue(stored.startsWith("$2"), "Expected a BCrypt hash, got: " + stored);
    }

    @Test
    void aWrongCurrentPasswordChangesNothing() {
        User saved = registerLoginUser();

        assertThrows(WrongPasswordException.class,
                () -> userService.changePassword(saved.getId(), "wrong", "newSecret456"));

        assertTrue(userService.authenticate("login@example.com", "secret123").isPresent(),
                "the old password must still work");
    }

    @Test
    void aNewPasswordOverTheByteLimitIsRefusedLikeAtRegistration() {
        User saved = registerLoginUser();

        // 37 Greek letters = 74 bytes: over the limit at only 37 characters.
        // The current password is right, so the error must be about the new
        // one - not "wrong password", which would send the user looking for
        // a mistake they did not make.
        assertThrows(IllegalStateException.class,
                () -> userService.changePassword(saved.getId(), "secret123", "κ".repeat(37)));

        assertTrue(userService.authenticate("login@example.com", "secret123").isPresent(),
                "the old password must still work");
    }

    @Test
    void aNewPasswordOfExactlyTheByteLimitIsAccepted() {
        User saved = registerLoginUser();
        String seventyTwoBytes = "κ".repeat(36);

        userService.changePassword(saved.getId(), "secret123", seventyTwoBytes);

        // The limit is "at most 72", as at registration: 72 itself is allowed.
        assertTrue(userService.authenticate("login@example.com", seventyTwoBytes).isPresent());
    }

    // --- limiting current-password guesses on a password change (B56 step 56b) ---
    // Same rule as login, but its own counter per user: someone holding a
    // stolen token must not get unlimited tries at the current password, and
    // their guessing must not lock the real user out of logging in.

    private void failPasswordChange(Integer userId, int times) {
        for (int i = 0; i < times; i++) {
            assertThrows(WrongPasswordException.class,
                    () -> userService.changePassword(userId, "wrong", "newSecret456"),
                    "attempt " + (i + 1) + " must still be told the password is wrong");
        }
    }

    @Test
    void fiveWrongCurrentPasswordsLockPasswordChangesEvenForTheRightOne() {
        User saved = registerWithPassword("change-lock@example.com");
        failPasswordChange(saved.getId(), 5);

        assertThrows(TooManyAttemptsException.class,
                () -> userService.changePassword(saved.getId(), "secret123", "newSecret456"));

        assertTrue(userService.authenticate("change-lock@example.com", "secret123").isPresent(),
                "the refused change must not have changed the password");
    }

    @Test
    void theRightCurrentPasswordResetsThePasswordChangeCount() {
        User saved = registerWithPassword("change-reset@example.com");
        failPasswordChange(saved.getId(), 4);
        userService.changePassword(saved.getId(), "secret123", "newSecret456");

        failPasswordChange(saved.getId(), 4);

        // 8 wrong in total, but never 5 in a row.
        assertDoesNotThrow(() -> userService.changePassword(saved.getId(), "newSecret456", "third789"));
    }

    @Test
    void aRightCurrentPasswordWithARefusedNewOneIsNotAGuess() {
        // The caller proved they know the password; only the new one is too
        // long. Counting that as a failure would lock out a user who knows
        // their password, after five tries at a new one.
        User saved = registerWithPassword("change-too-long@example.com");
        for (int i = 0; i < 5; i++) {
            assertThrows(IllegalStateException.class,
                    () -> userService.changePassword(saved.getId(), "secret123", "κ".repeat(37)));
        }

        assertDoesNotThrow(() -> userService.changePassword(saved.getId(), "secret123", "newSecret456"));
    }

    @Test
    void aLockedPasswordChangeDoesNotLockLogin() {
        User saved = registerWithPassword("change-not-login@example.com");
        failPasswordChange(saved.getId(), 5);

        assertTrue(userService.authenticate("change-not-login@example.com", "secret123").isPresent());
    }

    @Test
    void aLockedLoginDoesNotLockPasswordChange() {
        User saved = registerWithPassword("login-not-change@example.com");
        for (int i = 0; i < 5; i++) {
            userService.authenticate("login-not-change@example.com", "wrong");
        }

        // Someone typing wrong passwords at the login screen must not stop
        // the logged-in user from changing theirs - which is what they would
        // want to do after seeing that.
        assertDoesNotThrow(() -> userService.changePassword(saved.getId(), "secret123", "newSecret456"));
    }

    @Test
    void lockingOneUsersPasswordChangeLeavesTheOthersAlone() {
        User locked = registerWithPassword("change-locked-out@example.com");
        User bystander = registerWithPassword("change-bystander@example.com");
        failPasswordChange(locked.getId(), 5);

        assertDoesNotThrow(() -> userService.changePassword(bystander.getId(), "secret123", "newSecret456"));
    }
}
