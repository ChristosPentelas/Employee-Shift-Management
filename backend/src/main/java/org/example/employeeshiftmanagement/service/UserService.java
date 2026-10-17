package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.WrongPasswordException;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.UserRepository;

import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Optional;

@Service
public class UserService {

    /**
     * BCrypt hashes at most 72 bytes and Spring Security 7 rejects anything
     * longer instead of silently truncating it. Counted in bytes, not
     * characters: a Greek character takes two bytes in UTF-8.
     */
    public static final int MAX_PASSWORD_BYTES = 72;

    /** The staff list, alphabetical. */
    private static final Sort BY_NAME = Sort.by(Sort.Order.asc("name"), Sort.Order.asc("id"));

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final LoginAttemptService loginAttempts;

    /** Hash of a password nobody has; see authenticate. */
    private final String dummyHash;

    /**
     * Every dependency comes in through this one constructor (constructor
     * injection), so the list of what UserService needs is visible in one place
     * and the fields can be final. With a single constructor Spring uses it
     * automatically; no @Autowired needed.
     */
    public UserService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       LoginAttemptService loginAttempts) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.loginAttempts = loginAttempts;
        this.dummyHash = passwordEncoder.encode("no-user-has-this-password");
    }


    public Page<User> findAllUsers(Pageable pageable) {
        return userRepository.findAll(Paging.withSort(pageable, BY_NAME));
    }

    public User findUserById(Integer id) {
        return userRepository.findById(id).
                orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    /**
     * Like findUserById, but also locks the user's row (SELECT ... FOR UPDATE).
     * Any other transaction asking for the same lock waits here until this
     * one ends. Use it to make writes for one user happen one after another,
     * as ShiftService does so two overlapping shifts cannot both pass its check.
     *
     * The lock lasts until the caller's transaction ends - there is no
     * "unlock". MANDATORY makes calling this without a transaction an error:
     * the lock would be released the moment it was taken, protecting nothing.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public User findLockedUserById(Integer id) {
        return userRepository.findLockedById(id).
                orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }

    /**
     * Returns empty when no user has that email. A missing email is an expected
     * outcome here (a login attempt with an unknown address), not an error, so
     * the caller decides what it means rather than catching an exception.
     */
    public Optional<User> findUserByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    /**
     * Returns the user when the email exists and the password matches, empty
     * otherwise. The two failure cases are deliberately indistinguishable to the
     * caller: telling them apart would reveal which emails are registered.
     *
     * Throws TooManyAttemptsException after LoginAttemptService.MAX_FAILURES
     * failures in a row (B56) - even for the right password, or the change of
     * answer would tell a script it had found it.
     */
    public Optional<User> authenticate(String email, String rawPassword) {
        Optional<User> user = userRepository.findByEmail(email);

        // Counted per user, not per typed email: the tables' collation ignores
        // case and accents, so "Nikos@x.gr" and "nïkos@x.gr" both find
        // nikos@x.gr, and each spelling would otherwise get its own 5 tries.
        // An unknown email is counted too, so a 429 does not mean "registered".
        String key = user.map(found -> "login-user:" + found.getId())
                .orElse("login-email:" + email.toLowerCase(Locale.ROOT));
        // Before any BCrypt, the dummy hash included: a locked key gets no
        // answer about the password at all.
        loginAttempts.startAttempt(key);

        if (user.isEmpty()) {
            // Hash against a throwaway value anyway. Without it an unknown email
            // answers in about 0ms and a known one in about 100ms, so the
            // response time alone would reveal which emails are registered.
            passwordEncoder.matches(rawPassword, dummyHash);
            return Optional.empty();
        }

        // matches() re-hashes the typed password with the salt stored inside the
        // hash and compares in constant time, unlike String.equals.
        Optional<User> authenticated =
                user.filter(found -> passwordEncoder.matches(rawPassword, found.getPassword()));
        if (authenticated.isPresent()) {
            loginAttempts.succeeded(key);
        }
        return authenticated;
    }

    @Transactional
    public User registerNewEmployee(User user) {
        //Check if email already exists
        Optional<User> existingUser = userRepository.findByEmail(user.getEmail());

        if (existingUser.isPresent()) {
            throw new IllegalStateException("User already exists");
        }

        checkPasswordLength(user.getPassword());

        //Default role assignment
        if(user.getRole()==null || user.getRole().isEmpty()){
            user.setRole("EMPLOYEE");
        }

        // The plaintext never reaches the database: only this hash is stored.
        user.setPassword(passwordEncoder.encode(user.getPassword()));

        return userRepository.save(user);
    }

    /**
     * Creates a supervisor only when none exists yet, and returns whether it did.
     *
     * Registration is meant to be a supervisor's job, so someone has to create
     * the first one. Calling this on every startup is safe (idempotent): once a
     * supervisor exists it does nothing.
     *
     * Reuses registerNewEmployee, which keeps a role that is already set, so the
     * duplicate-email check, the byte limit and the hashing stay in one place.
     */
    @Transactional
    public boolean createFirstSupervisorIfNone(String name, String email, String rawPassword) {
        if (userRepository.existsByRole("SUPERVISOR")) {
            return false;
        }

        User supervisor = new User();
        supervisor.setName(name);
        supervisor.setEmail(email);
        supervisor.setPassword(rawPassword);
        supervisor.setRole("SUPERVISOR");

        registerNewEmployee(supervisor);
        return true;
    }

    @Transactional
    public User updateUser(Integer id,User userDetails) {

        User user = findUserById(id);

        //Check if the new email is already used by another user
        if(!user.getEmail().equals(userDetails.getEmail())) {
            Optional<User> userWithNewEmail = userRepository.findByEmail(userDetails.getEmail());
            if(userWithNewEmail.isPresent()) {
                throw new IllegalStateException("Email "+userDetails.getEmail()+" is already taken by another user");
            }
        }
        user.setEmail(userDetails.getEmail());
        user.setName(userDetails.getName());
        user.setPhoneNumber(userDetails.getPhoneNumber());


        return userRepository.save(user);

    }

    /**
     * Replaces the user's password, if the current one is right (B8).
     *
     * Wrong current password: WrongPasswordException. New one over
     * MAX_PASSWORD_BYTES: the same IllegalStateException as registration, so
     * the caller is told which of the two passwords is the problem.
     * After LoginAttemptService.MAX_FAILURES wrong current passwords in a row:
     * TooManyAttemptsException (429), even for the right one (B56).
     *
     * Like registration, only the hash of the new password is stored (F2).
     */
    @Transactional
    public void changePassword(Integer userId, String current, String newPassword) {
        User user = findUserById(userId);

        // Its own counter, not the login one (B56 step 56b): someone holding a
        // stolen token must not get unlimited guesses at the current password,
        // but their guessing must not lock the real user out of logging in -
        // nor someone at the login screen stop the user changing it here.
        String key = "password-change-user:" + userId;
        loginAttempts.startAttempt(key);

        // Guard clauses: each check throws on its own, so the error names the
        // password that is actually wrong, and the happy path ends unindented.
        if (!passwordEncoder.matches(current, user.getPassword())) {
            throw new WrongPasswordException();
        }
        // Right after the current password is proven, before the new one is
        // checked: a new password that is too long is not a guess, and must
        // not lock out a user who knows their password.
        loginAttempts.succeeded(key);
        checkPasswordLength(newPassword);

        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    /**
     * BCrypt's limit, shared by registration and password changes so the two
     * cannot drift apart: at most MAX_PASSWORD_BYTES, so exactly 72 is allowed.
     * An IllegalStateException (400) until B20 moves this into validation.
     */
    private static void checkPasswordLength(String rawPassword) {
        if (rawPassword.getBytes(StandardCharsets.UTF_8).length > MAX_PASSWORD_BYTES) {
            throw new IllegalStateException(
                    "Password must be at most " + MAX_PASSWORD_BYTES + " bytes");
        }
    }

    /**
     * Deletes the user; the database deletes or detaches everything that
     * points at them, from each foreign key's ON DELETE rule (V5): their
     * shifts, leave requests and messages go, their news posts stay with no
     * author. There is no list of tables here to keep up to date - a new table
     * that references users needs its own rule, which
     * UserDeletionIntegrationTest checks for.
     *
     * Those rows are removed by MySQL, behind Hibernate's back. Any of them
     * already loaded in the same transaction would be stale, so do not load
     * them here first.
     */
    @Transactional
    public void deleteUser(Integer id) {
        User user = findUserById(id);

        userRepository.delete(user);
    }
}
