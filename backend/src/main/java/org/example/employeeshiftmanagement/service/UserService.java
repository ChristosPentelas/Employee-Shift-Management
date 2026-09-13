package org.example.employeeshiftmanagement.service;

import jakarta.transaction.Transactional;
import org.springframework.stereotype.Service;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.example.employeeshiftmanagement.repository.ShiftRepository;
import org.example.employeeshiftmanagement.repository.LeaveRequestRepository;

import java.util.List;
import java.util.Optional;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final MessageRepository messageRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final ShiftRepository shiftRepository;

    /**
     * Every dependency comes in through this one constructor (constructor
     * injection), so the list of what UserService needs is visible in one place
     * and the fields can be final. With a single constructor Spring uses it
     * automatically; no @Autowired needed.
     */
    public UserService(UserRepository userRepository,
                       MessageRepository messageRepository,
                       LeaveRequestRepository leaveRequestRepository,
                       ShiftRepository shiftRepository) {
        this.userRepository = userRepository;
        this.messageRepository = messageRepository;
        this.leaveRequestRepository = leaveRequestRepository;
        this.shiftRepository = shiftRepository;
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
        return userRepository.findByEmail(email)
                .filter(user -> user.getPassword().equals(rawPassword));
    }

    public User registerNewEmployee(User user) {
        //Check if email already exists
        Optional<User> existingUser = userRepository.findByEmail(user.getEmail());

        if (existingUser.isPresent()) {
            throw new IllegalStateException("User already exists");
        }

        //Default role assignment
        if(user.getRole()==null || user.getRole().isEmpty()){
            user.setRole("EMPLOYEE");
        }

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
