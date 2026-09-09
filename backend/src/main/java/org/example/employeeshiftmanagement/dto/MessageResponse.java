package org.example.employeeshiftmanagement.dto;

import org.example.employeeshiftmanagement.model.Message;

import java.time.LocalDateTime;

/**
 * The component is named "read", not "isRead": Lombok generates isRead() for the
 * boolean field, so Jackson has always published the key as "read" and
 * Message.fromJson on the Flutter side reads json['read']. Renaming it here
 * would silently break every unread badge.
 */
public record MessageResponse(
        Integer id,
        String content,
        LocalDateTime timestamp,
        boolean read,
        UserResponse sender,
        UserResponse receiver
) {
    public static MessageResponse from(Message message) {
        return new MessageResponse(
                message.getId(),
                message.getContent(),
                message.getTimestamp(),
                message.isRead(),
                message.getSender() == null ? null : UserResponse.from(message.getSender()),
                message.getReceiver() == null ? null : UserResponse.from(message.getReceiver())
        );
    }
}
