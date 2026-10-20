package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * The message is the "detail" of every 404, so its shape is part of the API.
 * The controller tests cannot catch a change to it: they mock the service and
 * make up the exception themselves (B22).
 */
class ResourceNotFoundExceptionTest {

    @Test
    void theMessageNamesTheResourceAndTheId() {
        assertEquals("Shift not found: 3",
                new ResourceNotFoundException("Shift", 3).getMessage());
    }

    @Test
    void theIdCanBeWhateverTheCallerLookedUpBy() {
        assertEquals("User not found: nobody@example.com",
                new ResourceNotFoundException("User", "nobody@example.com").getMessage());
    }
}
