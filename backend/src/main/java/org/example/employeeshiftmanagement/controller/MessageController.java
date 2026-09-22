package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.config.CurrentUser;
import org.example.employeeshiftmanagement.dto.MessageRequest;
import org.example.employeeshiftmanagement.dto.MessageResponse;
import org.example.employeeshiftmanagement.dto.PageResponse;
import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.service.MessageService;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

/**
 * Messages are private to their sender and receiver - supervisors included
 * (decided 2026-09-15). Every rule below compares against the caller's token,
 * never against an id the client sent.
 *
 * Every list here is one page, newest first: {@code ?page=0&size=20} (F9).
 * See NewsItemController.getAllNews for the defaults and the cap.
 */
@RestController
@RequestMapping("/api/v1/messages")
public class MessageController {

    private final MessageService messageService;

    public MessageController(MessageService messageService) {
        this.messageService = messageService;
    }

    /**
     * The sender is always the caller. There used to be a senderId query
     * parameter, which let anyone send as anyone; clients that still send it
     * are unaffected, because Spring ignores query parameters it does not map.
     */
    @PostMapping
    public ResponseEntity<MessageResponse> sendMessage(Authentication authentication,
                                         @RequestParam Integer receiverId,
                                         @Valid @RequestBody MessageRequest request) {
        Message message = messageService.sendMessage(CurrentUser.id(authentication), receiverId, request.content());
        return new ResponseEntity<>(MessageResponse.from(message), HttpStatus.CREATED);
    }

    /**
     * Only a chat you are part of. Newest first, like every list here: page 0
     * is the latest messages, which the app shows oldest-to-newest.
     */
    @GetMapping("/chat")
    @PreAuthorize("#user1Id.toString() == authentication.name or #user2Id.toString() == authentication.name")
    public ResponseEntity<PageResponse<MessageResponse>> getChat(@RequestParam Integer user1Id,
                                                                 @RequestParam Integer user2Id,
                                                                 Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(
                messageService.getChatHistory(user1Id, user2Id, pageable), MessageResponse::from));
    }

    @GetMapping("/inbox/{userId}")
    @PreAuthorize("#userId.toString() == authentication.name")
    public ResponseEntity<PageResponse<MessageResponse>> getInbox(@PathVariable Integer userId, Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(
                messageService.getInbox(userId, pageable), MessageResponse::from));
    }

    @GetMapping("/sent/{userId}")
    @PreAuthorize("#userId.toString() == authentication.name")
    public ResponseEntity<PageResponse<MessageResponse>> getSent(@PathVariable Integer userId, Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(
                messageService.getSendMessages(userId, pageable), MessageResponse::from));
    }

    @GetMapping("/unread/{userId}")
    @PreAuthorize("#userId.toString() == authentication.name")
    public ResponseEntity<PageResponse<MessageResponse>> getUnread(@PathVariable Integer userId, Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(
                messageService.getUnreadMessages(userId, pageable), MessageResponse::from));
    }

    @PutMapping("/{messageId}/read")
    public ResponseEntity<MessageResponse> markRead(Authentication authentication,
                                                    @PathVariable Integer messageId) {
        return ResponseEntity.ok(MessageResponse.from(
                messageService.markAsRead(messageId, CurrentUser.id(authentication))));
    }

    @DeleteMapping("/{messageId}")
    public ResponseEntity<String> deleteMessage(Authentication authentication,
                                                @PathVariable Integer messageId) {
        messageService.deleteMessage(messageId, CurrentUser.id(authentication));
        // A plain string where every other delete answers 204 - see B21.
        return ResponseEntity.ok("Message deleted successfully");
    }
}
