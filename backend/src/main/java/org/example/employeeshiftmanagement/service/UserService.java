package org.example.employeeshiftmanagement.service;

import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
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

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private LeaveRequestRepository leaveRequestRepository;

    @Autowired
    private ShiftRepository shiftRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }


    public List<User> findAllUsers() {
        return userRepository.findAll();
    }

    public User findUserById(Integer id) {
        return userRepository.findById(id).
                orElseThrow(() -> new RuntimeException("User not found"));
    }

    public User findUserByEmail(String email) {
        return userRepository.findByEmail(email).
                orElseThrow(() -> new RuntimeException("User not found"));
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
