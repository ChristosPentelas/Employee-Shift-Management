package org.example.employeeshiftmanagement.service;

import jakarta.transaction.Transactional;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;

@Service
public class UserService {

    /**
     * BCrypt hashes at most 72 bytes and Spring Security 7 rejects anything
     * longer instead of silently truncating it. Counted in bytes, not
     * characters: a Greek character takes two bytes in UTF-8.
     */
    public static final int MAX_PASSWORD_BYTES = 72;

    private final UserRepository userRepository;
    private final MessageRepository messageRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final ShiftRepository shiftRepository;
    private final PasswordEncoder passwordEncoder;

    /** Hash of a password nobody has; see authenticate. */
    private final String dummyHash;

    /**
     * Every dependency comes in through this one constructor (constructor
     * injection), so the list of what UserService needs is visible in one place
     * and the fields can be final. With a single constructor Spring uses it
     * automatically; no @Autowired needed.
     */
    public UserService(UserRepository userRepository,
                       MessageRepository messageRepository,
                       LeaveRequestRepository leaveRequestRepository,
                       ShiftRepository shiftRepository,
                       PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.messageRepository = messageRepository;
        this.leaveRequestRepository = leaveRequestRepository;
        this.shiftRepository = shiftRepository;
        this.passwordEncoder = passwordEncoder;
        this.dummyHash = passwordEncoder.encode("no-user-has-this-password");
    }


    public List<User> findAllUsers() {
        return userRepository.findAll();
    }

    public User findUserById(Integer id) {
        return userRepository.findById(id).
                orElseThrow(() -> new RuntimeException("User not found"));
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
     */
    public Optional<User> authenticate(String email, String rawPassword) {
        Optional<User> user = userRepository.findByEmail(email);

        if (user.isEmpty()) {
            // Hash against a throwaway value anyway. Without it an unknown email
            // answers in about 0ms and a known one in about 100ms, so the
            // response time alone would reveal which emails are registered.
            passwordEncoder.matches(rawPassword, dummyHash);
            return Optional.empty();
        }

        // matches() re-hashes the typed password with the salt stored inside the
        // hash and compares in constant time, unlike String.equals.
        return user.filter(found -> passwordEncoder.matches(rawPassword, found.getPassword()));
    }

    public User registerNewEmployee(User user) {
        //Check if email already exists
        Optional<User> existingUser = userRepository.findByEmail(user.getEmail());

        if (existingUser.isPresent()) {
            throw new IllegalStateException("User already exists");
        }

        if (user.getPassword().getBytes(StandardCharsets.UTF_8).length > MAX_PASSWORD_BYTES) {
            throw new IllegalStateException(
                    "Password must be at most " + MAX_PASSWORD_BYTES + " bytes");
        }

        //Default role assignment
        if(user.getRole()==null || user.getRole().isEmpty()){
            user.setRole("EMPLOYEE");
        }

        // The plaintext never reaches the database: only this hash is stored.
        user.setPassword(passwordEncoder.encode(user.getPassword()));

        return userRepository.save(user);
    }

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


    @Transactional
    public void deleteUser(Integer id) {
        User user = findUserById(id);

        messageRepository.deleteBySenderId(user.getId());
        messageRepository.deleteByReceiverId(user.getId());
        leaveRequestRepository.deleteByUserId(user.getId());
        shiftRepository.deleteByUserId(user.getId());

        userRepository.delete(user);
    }
}
