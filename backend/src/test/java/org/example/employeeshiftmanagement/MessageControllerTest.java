package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.config.SecurityConfig;
import org.example.employeeshiftmanagement.controller.MessageController;
import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.service.MessageService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Messaging is open to every logged-in user, but only for their own messages.
 * The employee token's subject is 7 (TestTokens.EMPLOYEE_ID), the supervisor's 9.
 */
@WebMvcTest(value = MessageController.class, properties = TestProperties.JWT_SECRET_PROPERTY)
@Import({SecurityConfig.class, JwtConfig.class})
class MessageControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private MessageService messageService;

    private static Message message() {
        Message message = new Message();
        message.setId(1);
        message.setContent("Καλημέρα");
        message.setTimestamp(LocalDateTime.of(2026, 9, 9, 10, 30));
        message.setRead(false);
        message.setSender(TestUsers.supervisor());
        message.setReceiver(TestUsers.employee());
        return message;
    }

    @Test
    void theInboxLeaksNeitherSenderNorReceiverPassword() throws Exception {
        when(messageService.getInbox(7)).thenReturn(List.of(message()));

        mockMvc.perform(get("/api/v1/messages/inbox/7").with(TestTokens.employee()))
                .andExpect(status().isOk())
                // Message.fromJson reads sender.id, sender.name and the "read" key
                .andExpect(jsonPath("$[0].sender.id").value(9))
                .andExpect(jsonPath("$[0].sender.name").value("Boss"))
                .andExpect(jsonPath("$[0].read").value(false))
                .andExpect(jsonPath("$[0].sender.password").doesNotExist())
                .andExpect(jsonPath("$[0].receiver.password").doesNotExist());
    }

    @Test
    void theSenderIsTheCallerNotTheSenderIdInTheRequest() throws Exception {
        when(messageService.sendMessage(eq(7), eq(9), eq("Καλημέρα"))).thenReturn(message());

        mockMvc.perform(post("/api/v1/messages")
                        .with(TestTokens.employee())
                        // An old client, or an attacker, naming someone else as sender.
                        .param("senderId", "99")
                        .param("receiverId", "9")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"Καλημέρα\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.content").value("Καλημέρα"))
                .andExpect(jsonPath("$.sender.password").doesNotExist())
                .andExpect(jsonPath("$.receiver.password").doesNotExist());

        verify(messageService).sendMessage(eq(7), eq(9), eq("Καλημέρα"));
        verify(messageService, never()).sendMessage(eq(99), anyInt(), anyString());
    }

    @Test
    void sendingAnEmptyMessageIsRejected() throws Exception {
        mockMvc.perform(post("/api/v1/messages")
                        .with(TestTokens.employee())
                        .param("receiverId", "9")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void theInboxWithoutATokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/messages/inbox/7"))
                .andExpect(status().isUnauthorized());

        verify(messageService, never()).getInbox(anyInt());
    }

    @Test
    void anEmployeeCannotReadSomeoneElsesInbox() throws Exception {
        mockMvc.perform(get("/api/v1/messages/inbox/9").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(messageService, never()).getInbox(anyInt());
    }

    @Test
    void aSupervisorCannotReadAnEmployeesInboxEither() throws Exception {
        mockMvc.perform(get("/api/v1/messages/inbox/7").with(TestTokens.supervisor()))
                .andExpect(status().isForbidden());

        verify(messageService, never()).getInbox(anyInt());
    }

    @Test
    void anEmployeeCannotReadSomeoneElsesSentMessages() throws Exception {
        mockMvc.perform(get("/api/v1/messages/sent/9").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(messageService, never()).getSendMessages(anyInt());
    }

    @Test
    void aChatYouArePartOfCanBeRead() throws Exception {
        when(messageService.getChatHistory(7, 9)).thenReturn(List.of(message()));

        mockMvc.perform(get("/api/v1/messages/chat")
                        .param("user1Id", "7")
                        .param("user2Id", "9")
                        .with(TestTokens.employee()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].content").value("Καλημέρα"));
    }

    @Test
    void aChatBetweenTwoOtherPeopleIsForbidden() throws Exception {
        mockMvc.perform(get("/api/v1/messages/chat")
                        .param("user1Id", "9")
                        .param("user2Id", "3")
                        .with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(messageService, never()).getChatHistory(anyInt(), anyInt());
    }

    @Test
    void markingReadPassesTheCallerToTheService() throws Exception {
        Message read = message();
        read.setRead(true);
        when(messageService.markAsRead(1, 7)).thenReturn(read);

        mockMvc.perform(put("/api/v1/messages/1/read").with(TestTokens.employee()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.read").value(true));
    }

    @Test
    void aRefusedMarkAsReadIsForbiddenNotNotFound() throws Exception {
        when(messageService.markAsRead(1, 9))
                .thenThrow(new AccessDeniedException("Only the receiver can mark a message as read"));

        // Before 7a the controller's catch-all turned every exception into 404.
        mockMvc.perform(put("/api/v1/messages/1/read").with(TestTokens.supervisor()))
                .andExpect(status().isForbidden());
    }

    @Test
    void aRefusedDeleteIsForbiddenNotNotFound() throws Exception {
        doThrow(new AccessDeniedException("Only the sender can delete a message"))
                .when(messageService).deleteMessage(1, 7);

        mockMvc.perform(delete("/api/v1/messages/1").with(TestTokens.employee()))
                .andExpect(status().isForbidden());
    }
}
