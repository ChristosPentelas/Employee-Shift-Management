package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.dto.MessageRequest;
import org.example.employeeshiftmanagement.dto.MessageResponse;
import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.service.MessageService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/messages")
public class MessageController {

    private final MessageService messageService;

    public MessageController(MessageService messageService) {
        this.messageService = messageService;
    }

    @PostMapping
    public ResponseEntity<?> sendMessage(@RequestParam Integer senderId,
                                         @RequestParam Integer receiverId,
                                         @Valid @RequestBody MessageRequest request) {
        try{
            Message message = messageService.sendMessage(senderId, receiverId, request.content());
            return new ResponseEntity<>(MessageResponse.from(message), HttpStatus.CREATED);
        }catch (Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping("/chat")
    public ResponseEntity<List<MessageResponse>> getChat(@RequestParam Integer user1Id,@RequestParam Integer user2Id) {
        return ResponseEntity.ok(toResponses(messageService.getChatHistory(user1Id, user2Id)));
    }

    @GetMapping("/inbox/{userId}")
    public ResponseEntity<List<MessageResponse>> getInbox(@PathVariable Integer userId) {
        return ResponseEntity.ok(toResponses(messageService.getInbox(userId)));
    }

    @GetMapping("/sent/{userId}")
    public ResponseEntity<List<MessageResponse>> getSent(@PathVariable Integer userId) {
        return ResponseEntity.ok(toResponses(messageService.getSendMessages(userId)));
    }

    @GetMapping("/unread/{userId}")
    public ResponseEntity<List<MessageResponse>> getUnread(@PathVariable Integer userId) {
        return ResponseEntity.ok(toResponses(messageService.getUnreadMessages(userId)));
    }

    @PutMapping("/{messageId}/read")
    public ResponseEntity<?> markRead(@PathVariable Integer messageId) {
        try{
            return ResponseEntity.ok(MessageResponse.from(messageService.markAsRead(messageId)));
        }catch (Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @DeleteMapping("/{messageId}")
    public ResponseEntity<?> deleteMessage(@PathVariable Integer messageId) {
        try{
            messageService.deleteMessage(messageId);
            return ResponseEntity.ok("Message deleted successfully");
        }catch (Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    private static List<MessageResponse> toResponses(List<Message> messages) {
        return messages.stream().map(MessageResponse::from).toList();
    }
}
