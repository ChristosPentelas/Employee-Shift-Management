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
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

/**
 * Messages are private to their sender and receiver - supervisors included
 * (decided 2026-09-15). Every rule below compares against the caller's token,
 * never against an id the client sent.
 *
 * Every list here is one page, newest first: {@code ?page=0&size=20} (F9).
 * See NewsItemController.getAllNews for the defaults and the cap.
 *
 * Every id in a path is {@code \\d+}, digits only (B83). Spring matches the
 * path before it converts the id, so a bare {@code {messageId}} would read
 * "/messages/chat" as a message called "chat": a removed or mistyped path
 * answered 405 or 400 instead of 404.
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
     * The caller's chat with otherUserId. Newest first, like every list here:
     * page 0 is the latest messages, which the app shows oldest-to-newest.
     *
     * The caller comes from the token, so there is no @PreAuthorize:
     * otherUserId only picks which of the caller's own chats to read, and no
     * value of it reaches anyone else's (B48). Like PUT /chat/{otherUserId}/read.
     */
    @GetMapping("/chat/{otherUserId:\\d+}")
    public ResponseEntity<PageResponse<MessageResponse>> getChatWith(Authentication authentication,
                                                                     @PathVariable Integer otherUserId,
                                                                     Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(
                messageService.getChatHistory(CurrentUser.id(authentication), otherUserId, pageable),
                MessageResponse::from));
    }

    /**
     * The caller's conversations: one row per person, holding the newest
     * message between them (whoever sent it), newest conversation first. Not
     * a list of every message - the chat endpoint is that.
     *
     * Only the token says whose conversations these are, so there is no id in
     * the URL to check and no @PreAuthorize (B48).
     */
    @GetMapping("/conversations")
    public ResponseEntity<PageResponse<MessageResponse>> getConversations(Authentication authentication,
                                                                          Pageable pageable) {
        return ResponseEntity.ok(PageResponse.from(
                messageService.getConversations(CurrentUser.id(authentication), pageable), MessageResponse::from));
    }

    @PutMapping("/{messageId:\\d+}/read")
    public ResponseEntity<MessageResponse> markRead(Authentication authentication,
                                                    @PathVariable Integer messageId) {
        return ResponseEntity.ok(MessageResponse.from(
                messageService.markAsRead(messageId, CurrentUser.id(authentication))));
    }

    /**
     * The URL names only the other person, and the receiver is always the caller.
     *  That's why there is no @PreAuthorize: there's nobody else's data this request could touch.
     */
    @PutMapping("/chat/{otherUserId:\\d+}/read")
    public ResponseEntity<Void> markChatRead(Authentication authentication, @PathVariable Integer otherUserId) {
        messageService.markChatAsRead(otherUserId, CurrentUser.id(authentication));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{messageId:\\d+}")
    public ResponseEntity<Void> deleteMessage(Authentication authentication,
                                              @PathVariable Integer messageId) {
        messageService.deleteMessage(messageId, CurrentUser.id(authentication));
        return ResponseEntity.noContent().build();
    }
}
