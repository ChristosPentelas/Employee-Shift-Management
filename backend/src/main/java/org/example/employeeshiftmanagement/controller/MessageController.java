package org.example.employeeshiftmanagement.controller;

import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.MessageRequest;
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
                                         @RequestBody MessageRequest request) {
        try{
            Message message = messageService.sendMessage(senderId, receiverId, request.getContent());
            return new ResponseEntity<>(message,HttpStatus.CREATED);
        }catch (Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping("/chat")
    public ResponseEntity<List<Message>> getChat(@RequestParam Integer user1Id,@RequestParam Integer user2Id) {
        return ResponseEntity.ok(messageService.getChatHistory(user1Id, user2Id));
    }

    @GetMapping("/inbox/{userId}")
    public ResponseEntity<List<Message>> getInbox(@PathVariable Integer userId) {
        return ResponseEntity.ok(messageService.getInbox(userId));
    }

    @GetMapping("/sent/{userId}")
    public ResponseEntity<List<Message>> getSent(@PathVariable Integer userId) {
        return ResponseEntity.ok(messageService.getSendMessages(userId));
    }

    @GetMapping("/unread/{userId}")
    public ResponseEntity<List<Message>> getUnread(@PathVariable Integer userId) {
        return ResponseEntity.ok(messageService.getUnreadMessages(userId));
    }

    @PutMapping("/{messageId}/read")
    public ResponseEntity<?> markRead(@PathVariable Integer messageId) {
        try{
            return ResponseEntity.ok(messageService.markAsRead(messageId));
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


}
