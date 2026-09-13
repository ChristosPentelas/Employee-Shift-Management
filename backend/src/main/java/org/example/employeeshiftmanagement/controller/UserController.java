package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.dto.LoginRequest;
import org.example.employeeshiftmanagement.dto.RegisterRequest;
import org.example.employeeshiftmanagement.dto.UpdateUserRequest;
import org.example.employeeshiftmanagement.dto.UserResponse;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.service.UserService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("api/v1/users")
public class UserController {
    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public ResponseEntity<?> registerUser(@Valid @RequestBody RegisterRequest request) {
        try {
            User savedUser = userService.registerNewEmployee(toNewUser(request));
            return new ResponseEntity<>(UserResponse.from(savedUser), HttpStatus.CREATED);
        }catch (IllegalStateException e){
            return new ResponseEntity<>(e.getMessage(), HttpStatus.BAD_REQUEST);
        }
    }

    @GetMapping
    public ResponseEntity<List<UserResponse>> getAllUsers() {
        List<UserResponse> users = userService.findAllUsers()
                .stream()
                .map(UserResponse::from)
                .toList();
        return ResponseEntity.ok(users);
    }

    @GetMapping("/{userId}")
    public ResponseEntity<UserResponse> getUserById(@PathVariable("userId") Integer id) {
        try {
            User user = userService.findUserById(id);
            return ResponseEntity.ok(UserResponse.from(user));
        }catch (RuntimeException e){
            return new ResponseEntity<>(HttpStatus.NOT_FOUND);
        }
    }

    @GetMapping("/search")
    public ResponseEntity<UserResponse> getUserByEmail(@RequestParam String email) {
        return userService.findUserByEmail(email)
                .map(user -> ResponseEntity.ok(UserResponse.from(user)))
                .orElseGet(() -> new ResponseEntity<>(HttpStatus.NOT_FOUND));
    }

    @PutMapping("/{userId}")
    public ResponseEntity<?> updateUser(@PathVariable("userId") Integer id,
                                        @Valid @RequestBody UpdateUserRequest request) {
        try{
            User updatedUser = userService.updateUser(id, toUserDetails(request));
            return ResponseEntity.ok(UserResponse.from(updatedUser));
        }catch (Exception e){
            return new ResponseEntity<>(e.getMessage(), HttpStatus.BAD_REQUEST);
        }
    }

    @DeleteMapping("/{userId}")
    public ResponseEntity<Void> deleteUser(@PathVariable("userId") Integer id) {
        try{
            userService.deleteUser(id);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        }catch (RuntimeException e){
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest loginRequest) {
        Optional<User> user = userService.authenticate(loginRequest.email(), loginRequest.password());

        if (user.isPresent()) {
            return ResponseEntity.ok(UserResponse.from(user.get()));
        }
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Λάθος email ή password");
    }

    /**
     * The role is left unset on purpose: UserService.registerNewEmployee assigns
     * EMPLOYEE when none is present, so the client cannot promote itself.
     */
    private User toNewUser(RegisterRequest request) {
        User user = new User();
        user.setName(request.name());
        user.setEmail(request.email());
        user.setPhoneNumber(request.phoneNumber());
        user.setPassword(request.password());
        return user;
    }

    /** Carries the three editable fields into UserService.updateUser; never persisted itself. */
    private User toUserDetails(UpdateUserRequest request) {
        User user = new User();
        user.setName(request.name());
        user.setEmail(request.email());
        user.setPhoneNumber(request.phoneNumber());
        return user;
    }
}
