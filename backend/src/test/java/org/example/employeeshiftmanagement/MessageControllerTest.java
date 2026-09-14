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
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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

        mockMvc.perform(get("/api/v1/messages/inbox/7").with(jwt()))
                .andExpect(status().isOk())
                // Message.fromJson reads sender.id, sender.name and the "read" key
                .andExpect(jsonPath("$[0].sender.id").value(9))
                .andExpect(jsonPath("$[0].sender.name").value("Boss"))
                .andExpect(jsonPath("$[0].read").value(false))
                .andExpect(jsonPath("$[0].sender.password").doesNotExist())
                .andExpect(jsonPath("$[0].receiver.password").doesNotExist());
    }

    @Test
    void sendingAMessageDoesNotLeakPasswords() throws Exception {
        when(messageService.sendMessage(eq(9), eq(7), eq("Καλημέρα"))).thenReturn(message());

        mockMvc.perform(post("/api/v1/messages")
                        .with(jwt())
                        .param("senderId", "9")
                        .param("receiverId", "7")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"Καλημέρα\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.content").value("Καλημέρα"))
                .andExpect(jsonPath("$.sender.password").doesNotExist())
                .andExpect(jsonPath("$.receiver.password").doesNotExist());
    }

    @Test
    void sendingAnEmptyMessageIsRejected() throws Exception {
        mockMvc.perform(post("/api/v1/messages")
                        .with(jwt())
                        .param("senderId", "9")
                        .param("receiverId", "7")
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
}
