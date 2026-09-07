package org.example.employeeshiftmanagement.model;

import lombok.Getter;
import lombok.Setter;

/**
 * Data Transfer Object (DTO) for message requests.
 * Used to ensure robust JSON serialization (especially for Greek characters)
 * and to allow future API extensibility without modifying the Database Entity.
 */
@Getter
@Setter
public class MessageRequest {
    private String content;
}
