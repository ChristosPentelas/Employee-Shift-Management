package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.MessageRepository;
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

    //Mark a message as read
    public Message markAsRead(Integer messageId){
        Message message = messageRepository.findById(messageId).
                orElseThrow(() -> new RuntimeException("Message not found"));
        message.setRead(true);
        return messageRepository.save(message);
    }

    public void deleteMessage(Integer messageId) {
        if (!messageRepository.existsById(messageId)){
            throw new RuntimeException("Message not found");
        }

        messageRepository.deleteById(messageId);
    }
}
