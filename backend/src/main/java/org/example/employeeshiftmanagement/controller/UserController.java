package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.dto.LoginRequest;
import org.example.employeeshiftmanagement.dto.LoginResponse;
import org.example.employeeshiftmanagement.dto.PageResponse;
import org.example.employeeshiftmanagement.dto.RegisterRequest;
import org.example.employeeshiftmanagement.dto.UpdateUserRequest;
import org.example.employeeshiftmanagement.dto.UserResponse;
import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.service.TokenService;
import org.example.employeeshiftmanagement.service.UserService;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping("api/v1/users")
public class UserController {
    private final UserService userService;
    private final TokenService tokenService;

    public UserController(UserService userService, TokenService tokenService) {
        this.userService = userService;
        this.tokenService = tokenService;
    }

    /** Only supervisors create accounts; nobody signs themselves up (F1 step 6). */
    @PostMapping
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<UserResponse> registerUser(@Valid @RequestBody RegisterRequest request) {
        User savedUser = userService.registerNewEmployee(toNewUser(request));
        return new ResponseEntity<>(UserResponse.from(savedUser), HttpStatus.CREATED);
    }

    /** One page of the staff list, by name (F9). See NewsItemController.getAllNews for the defaults and the cap. */
    @GetMapping
    public ResponseEntity<PageResponse<UserResponse>> getAllUsers(Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(userService.findAllUsers(pageable), UserResponse::from));
    }

    @GetMapping("/{userId}")
    public ResponseEntity<UserResponse> getUserById(@PathVariable("userId") Integer id) {
        return ResponseEntity.ok(UserResponse.from(userService.findUserById(id)));
    }

    /** Not used by the app; left open it lets anyone test which emails are registered. */
    @GetMapping("/search")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<UserResponse> getUserByEmail(@RequestParam String email) {
        User user = userService.findUserByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
        return ResponseEntity.ok(UserResponse.from(user));
    }

    @PutMapping("/{userId}")
    // Your own profile only - not even a supervisor: this email is the name
    // its owner logs in with (decided 2026-09-15).
    @PreAuthorize("#id.toString() == authentication.name")
    public ResponseEntity<UserResponse> updateUser(@PathVariable("userId") Integer id,
                                                   @Valid @RequestBody UpdateUserRequest request) {
        User updatedUser = userService.updateUser(id, toUserDetails(request));
        return ResponseEntity.ok(UserResponse.from(updatedUser));
    }

    @DeleteMapping("/{userId}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<Void> deleteUser(@PathVariable("userId") Integer id) {
        userService.deleteUser(id);
        return new ResponseEntity<>(HttpStatus.NO_CONTENT);
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest loginRequest) {
        Optional<User> user = userService.authenticate(loginRequest.email(), loginRequest.password());

        if (user.isPresent()) {
            String token = tokenService.issueToken(user.get());
            return ResponseEntity.ok(LoginResponse.from(user.get(), token));
        }
        // English, in the standard error shape. The app picks the Greek text it
        // shows from the 401 itself (login_screen.dart), so user-facing wording
        // stays in the UI and a second client is not stuck with our language (B2).
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(ProblemDetail.forStatusAndDetail(
                        HttpStatus.UNAUTHORIZED, "Invalid email or password"));
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
