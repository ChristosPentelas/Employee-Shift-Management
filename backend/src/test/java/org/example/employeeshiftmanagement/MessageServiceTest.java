package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.example.employeeshiftmanagement.service.MessageService;
import org.example.employeeshiftmanagement.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Plain unit test for the message ownership rules: no Spring, no Docker.
 * Message 1 was sent by the supervisor (9) to the employee (7).
 */
class MessageServiceTest {

    private final MessageRepository messageRepository = mock(MessageRepository.class);
    private final MessageService messageService =
            new MessageService(messageRepository, mock(UserService.class));

    private Message storedMessage() {
        Message message = new Message();
        message.setId(1);
        message.setContent("Καλημέρα");
        message.setRead(false);
        message.setSender(TestUsers.supervisor());
        message.setReceiver(TestUsers.employee());
        when(messageRepository.findById(1)).thenReturn(Optional.of(message));
        when(messageRepository.save(any(Message.class))).thenAnswer(call -> call.getArgument(0));
        return message;
    }

    @Test
    void theReceiverCanMarkAMessageAsRead() {
        storedMessage();

        Message result = messageService.markAsRead(1, 7);

        assertTrue(result.isRead());
    }

    @Test
    void nobodyElseCanMarkAMessageAsRead() {
        storedMessage();

        // Not even the sender: a read receipt must mean the receiver read it.
        assertThrows(AccessDeniedException.class, () -> messageService.markAsRead(1, 9));
        verify(messageRepository, never()).save(any());
    }

    @Test
    void theSenderCanDeleteAMessage() {
        Message message = storedMessage();

        messageService.deleteMessage(1, 9);

        verify(messageRepository).delete(message);
    }

    @Test
    void nobodyElseCanDeleteAMessage() {
        storedMessage();

        assertThrows(AccessDeniedException.class, () -> messageService.deleteMessage(1, 7));
        verify(messageRepository, never()).delete(any(Message.class));
    }
}
