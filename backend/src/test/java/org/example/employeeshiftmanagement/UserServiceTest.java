package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
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

        User savedUser = userService.registerNewEmployee(user);
        assertNotNull(savedUser.getId(), "Το Id δεν πρέπει να είναι null μετά την αποθήκευση");

        User found = userService.findUserById(savedUser.getId());
        assertEquals("Test User", found.getName());

        List<User> users = userService.findAllUsers();
        assertTrue(users.size() > 0);

        assertEquals("EMPLOYEE", savedUser.getRole(), "Θα έπρεπε να έχει μπεί το default role EMPLOYEE");
        assertEquals("test@example.com", savedUser.getEmail());
    }

    @Test
    void testUpdateUser() {
        User user = new User();
        user.setName("Test User");
        user.setEmail("initial@example.com");
        user.setPassword("123456");
        User savedUser = userService.registerNewEmployee(user);

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
        User savedUser = userService.registerNewEmployee(user);

        assertDoesNotThrow(() -> userService.deleteUser(savedUser.getId()));

        //Verify deletion
        assertThrows(RuntimeException.class, () -> userService.findUserById(savedUser.getId()));
    }

    @Test
    void testRegisterUserWithExistingEmail() {
        User user1 = new User();
        user1.setName("Test User1");
        user1.setEmail("same@email.com");
        user1.setPassword("123456");
        user1.setRole("EMPLOYEE");
        userService.registerNewEmployee(user1);

        User user2 = new User();
        user2.setName("Test User2");
        user2.setEmail("same@email.com");
        user2.setPassword("123456");

        assertThrows(IllegalStateException.class, () -> {
            userService.registerNewEmployee(user2);
        });
    }

    @Test
    void testFindUserByEmail() {

        User user1 = new User();
        user1.setName("Test User1");
        user1.setEmail("findme@example.com");
        user1.setPassword("123456");
        userService.registerNewEmployee(user1);

        User found = userService.findUserByEmail(user1.getEmail());

        assertNotNull(found);
        assertEquals("Test User1", found.getName());

        assertThrows(RuntimeException.class, () ->
                userService.findUserByEmail("false@example.com"));
    }

    @Test
    void testUpdateUserWithExistingEmail() {
        User userA = new User();
        userA.setName("User A");
        userA.setEmail("userA@example.com");
        userA.setPassword("password");
        userService.registerNewEmployee(userA);

        User userB = new User();
        userB.setName("User B");
        userB.setEmail("userB@example.com");
        userB.setPassword("password");
        User savedB = userService.registerNewEmployee(userB);

        User updateDetails = new User();
        updateDetails.setName("Updated User B");
        updateDetails.setEmail("userA@example.com");

        assertThrows(IllegalStateException.class, () -> {
            userService.updateUser(savedB.getId(), updateDetails);
        });
    }
}
