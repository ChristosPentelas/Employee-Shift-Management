package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.config.SecurityConfig;
import org.example.employeeshiftmanagement.controller.UserController;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.service.TokenService;
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
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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
 *
 * Login requests deliberately carry no token: login must stay reachable
 * without one. Creating accounts needs a supervisor (F1 step 6).
 */
@WebMvcTest(value = UserController.class, properties = TestProperties.JWT_SECRET_PROPERTY)
@Import({SecurityConfig.class, JwtConfig.class})
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @MockitoBean
    private TokenService tokenService;

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

    private static final String NEW_ACCOUNT = """
            {"name":"Test User","email":"test@example.com","password":"secret123"}
            """;

    @Test
    void registrationIgnoresAClientSuppliedRole() throws Exception {
        when(userService.registerNewEmployee(any(User.class))).thenReturn(existingUser());

        mockMvc.perform(post("/api/v1/users")
                        .with(TestTokens.supervisor())
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
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEW_ACCOUNT))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.role").value("EMPLOYEE"));
    }

    @Test
    void registrationRejectsABlankEmail() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Test User","email":"","password":"secret123"}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void registrationWithoutATokenIsUnauthorized() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEW_ACCOUNT))
                .andExpect(status().isUnauthorized());

        verify(userService, never()).registerNewEmployee(any());
    }

    @Test
    void anEmployeeCannotCreateAccounts() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(NEW_ACCOUNT))
                .andExpect(status().isForbidden());

        verify(userService, never()).registerNewEmployee(any());
    }

    @Test
    void anEmployeeCannotDeleteUsers() throws Exception {
        mockMvc.perform(delete("/api/v1/users/7").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(userService, never()).deleteUser(anyInt());
    }

    @Test
    void anEmployeeCannotSearchUsersByEmail() throws Exception {
        mockMvc.perform(get("/api/v1/users/search")
                        .param("email", "test@example.com")
                        .with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(userService, never()).findUserByEmail(anyString());
    }

    @Test
    void loginReturnsTheRoleAndATokenButNotThePassword() throws Exception {
        when(userService.authenticate(anyString(), anyString())).thenReturn(Optional.of(existingUser()));
        when(tokenService.issueToken(any(User.class))).thenReturn("test-token");

        mockMvc.perform(post("/api/v1/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"test@example.com","password":"secret123"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.role").value("EMPLOYEE"))
                // Top-level user fields must stay where they are: the app's
                // User.fromJson reads them from here (F1 step 2).
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.token").value("test-token"));
    }

    @Test
    void loginWithAnUnknownEmailIsUnauthorizedNotAServerError() throws Exception {
        when(userService.authenticate(anyString(), anyString())).thenReturn(Optional.empty());

        mockMvc.perform(post("/api/v1/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"nobody@example.com","password":"secret123"}
                                """))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void loginWithAWrongPasswordIsUnauthorizedAndGetsNoToken() throws Exception {
        when(userService.authenticate(anyString(), anyString())).thenReturn(Optional.empty());

        mockMvc.perform(post("/api/v1/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"test@example.com","password":"wrong"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.token").doesNotExist());

        verify(tokenService, never()).issueToken(any());
    }

    @Test
    void loginRejectsABlankEmailWithoutQueryingTheDatabase() throws Exception {
        mockMvc.perform(post("/api/v1/users/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"","password":"secret123"}
                                """))
                .andExpect(status().isBadRequest());

        verify(userService, never()).authenticate(any(), any());
    }

    @Test
    void listingUsersDoesNotLeakPasswords() throws Exception {
        when(userService.findAllUsers()).thenReturn(List.of(existingUser()));

        // An employee on purpose: the app opens chats from the employee list.
        mockMvc.perform(get("/api/v1/users").with(TestTokens.employee()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].email").value("test@example.com"))
                .andExpect(jsonPath("$[0].password").doesNotExist());
    }

    @Test
    void listingUsersWithoutATokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/users"))
                .andExpect(status().isUnauthorized());

        verify(userService, never()).findAllUsers();
    }
}
