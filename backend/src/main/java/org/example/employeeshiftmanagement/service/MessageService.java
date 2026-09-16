package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class MessageService {

    private final MessageRepository messageRepository;
    private final UserService userService;

    public MessageService(MessageRepository messageRepository, UserService userService) {
        this.messageRepository = messageRepository;
        this.userService = userService;
    }

    /** senderId must come from the caller's token (CurrentUser), never from the request. */
    public Message sendMessage(Integer senderId, Integer receiverId, String content) {
        User sender = userService.findUserById(senderId);
        User receiver = userService.findUserById(receiverId);

        Message message = new Message();
        message.setSender(sender);
        message.setReceiver(receiver);
        message.setContent(content);

        return messageRepository.save(message);
    }

    public List<Message> getChatHistory(Integer user1Id, Integer user2Id) {
        return messageRepository.findBySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(user1Id, user2Id,
                user2Id, user1Id);
    }

    public List<Message> getInbox(Integer userId) {
        return messageRepository.findByReceiverIdOrderByTimestampDesc(userId);
    }

    public List<Message> getSendMessages(Integer userId) {
        return messageRepository.findBySenderIdOrderByTimestampDesc(userId);
    }

    public List<Message> getUnreadMessages(Integer userId) {
        return messageRepository.findByReceiverIdAndIsReadFalse(userId);
    }

    /**
     * Only the receiver can mark a message as read; anyone else doing it would
     * fake a read receipt.
     *
     * This rule needs the message loaded first, which is why it lives here and
     * not in a @PreAuthorize on the controller.
     */
    public Message markAsRead(Integer messageId, Integer currentUserId) {
        Message message = findMessage(messageId);

        if (!message.getReceiver().getId().equals(currentUserId)) {
            throw new AccessDeniedException("Only the receiver can mark a message as read");
        }

        message.setRead(true);
        return messageRepository.save(message);
    }

    /** Only the sender can delete a message. */
    public void deleteMessage(Integer messageId, Integer currentUserId) {
        Message message = findMessage(messageId);

        if (!message.getSender().getId().equals(currentUserId)) {
            throw new AccessDeniedException("Only the sender can delete a message");
        }

        messageRepository.delete(message);
    }

    private Message findMessage(Integer messageId) {
        return messageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message not found"));
    }
}
