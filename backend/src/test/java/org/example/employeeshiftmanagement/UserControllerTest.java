package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.SecurityConfig;
import org.example.employeeshiftmanagement.controller.UserController;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Contract tests for the users API.
 *
 * @WebMvcTest loads only the web layer, so these run without Docker and without
 * MySQL - unlike UserServiceTest, which needs a Testcontainers database.
 *
 * The password assertions are regression tests for F3: the User entity has no
 * @JsonIgnore on its password, so serialising the entity would leak it. They
 * fail the moment someone returns a User from a controller again.
 */
@WebMvcTest(UserController.class)
@Import(SecurityConfig.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    private static User existingUser() {
        User user = new User();
        user.setId(1);
        user.setName("Test User");
        user.setEmail("test@example.com");
        user.setPhoneNumber("1234567890");
        user.setPassword("secret123");
        user.setRole("EMPLOYEE");
        return user;
    }

    @Test
    void registrationIgnoresAClientSuppliedRole() throws Exception {
        when(userService.registerNewEmployee(any(User.class))).thenReturn(existingUser());

        mockMvc.perform(post("/api/v1/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Test User","email":"test@example.com",
                                 "password":"secret123","role":"SUPERVISOR","id":99}
                                """))
                .andExpect(status().isCreated());

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userService).registerNewEmployee(captor.capture());

        assertNull(captor.getValue().getRole(),
                "A client must not be able to choose its own role (F5)");
        assertNull(captor.getValue().getId(),
                "A client must not be able to choose its own id (F6)");
    }

    @Test
    void registrationResponseDoesNotLeakThePassword() throws Exception {
        when(userService.registerNewEmployee(any(User.class))).thenReturn(existingUser());

        mockMvc.perform(post("/api/v1/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Test User","email":"test@example.com","password":"secret123"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.role").value("EMPLOYEE"));
    }

    @Test
    void registrationRejectsABlankEmail() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Test User","email":"","password":"secret123"}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void loginReturnsTheRoleButNotThePassword() throws Exception {
        when(userService.findUserByEmail(anyString())).thenReturn(existingUser());

        mockMvc.perform(post("/api/v1/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"test@example.com","password":"secret123"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.role").value("EMPLOYEE"));
    }

    @Test
    void listingUsersDoesNotLeakPasswords() throws Exception {
        when(userService.findAllUsers()).thenReturn(List.of(existingUser()));

        mockMvc.perform(get("/api/v1/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].email").value("test@example.com"))
                .andExpect(jsonPath("$[0].password").doesNotExist());
    }
}
