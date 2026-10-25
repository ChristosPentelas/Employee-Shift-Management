package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.model.Message;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.MessageRepository;
import org.example.employeeshiftmanagement.repository.UserRepository;
import org.example.employeeshiftmanagement.service.MessageService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * The conversation list: the caller's newest message with each person (B26
 * step 26c1). Before it, the app merged page 0 of the inbox and of sent on the
 * phone, so a conversation older than both pages was missing.
 *
 * <p>The controller test mocks the service, so it cannot see the query. This
 * one runs it against MySQL: that it parses, groups by the other person
 * whoever sent the message, and that its count query pages correctly.
 *
 * <p>{@code @Transactional}: the query only reads, so a test transaction hides
 * nothing here (unlike ChatReadIntegrationTest's UPDATE), and rolling back
 * keeps the rows away from the other tests sharing this container.
 */
@SpringBootTest(properties = {TestProperties.JWT_SECRET_PROPERTY, TestProperties.NO_SUPERVISOR_SEEDING})
@Import(TestcontainersConfiguration.class)
@Transactional
class ConversationsIntegrationTest {

    @Autowired private MessageService messageService;
    @Autowired private UserRepository userRepository;
    @Autowired private MessageRepository messageRepository;

    @Test
    void eachPersonIsOneRowWithTheirNewestMessageWhoeverSentIt() {
        User me = user("me");
        User anna = user("anna");
        User bob = user("bob");
        message(me, anna, "1 to anna");
        message(anna, me, "2 from anna"); // newest with anna: she sent it
        message(bob, me, "3 from bob");
        message(me, bob, "4 to bob");     // newest with bob: I sent it

        // Newest conversation first: bob's 4 is newer than anna's 2.
        assertEquals(List.of("4 to bob", "2 from anna"), contents(conversations(me, 0, 20)));
    }

    @Test
    void aMessageToYourselfIsOneRow() {
        User me = user("me");
        message(me, me, "note to self");
        message(me, me, "another note");

        assertEquals(List.of("another note"), contents(conversations(me, 0, 20)));
    }

    @Test
    void otherPeoplesChatsAreNotListed() {
        User me = user("me");
        User anna = user("anna");
        User bob = user("bob");
        message(me, anna, "mine");
        message(anna, bob, "between anna and bob");

        assertEquals(List.of("mine"), contents(conversations(me, 0, 20)));
    }

    @Test
    void conversationsArePagedAndCountedAsConversations() {
        User me = user("me");
        User carl = user("carl");
        message(me, user("anna"), "to anna");
        message(me, user("bob"), "to bob");
        message(me, carl, "to carl");
        message(me, carl, "to carl again"); // a 4th message, still 3 conversations

        // Page 0 is full, so Spring runs the count query: it must count
        // conversations, not messages.
        Page<Message> first = conversations(me, 0, 2);
        assertEquals(3, first.getTotalElements());
        assertEquals(2, first.getTotalPages());
        assertEquals(List.of("to carl again", "to bob"), contents(first));

        assertEquals(List.of("to anna"), contents(conversations(me, 1, 2)));
    }

    @Test
    void someoneWithNoMessagesHasNoConversations() {
        User me = user("me");
        message(user("anna"), user("bob"), "not mine");

        Page<Message> page = conversations(me, 0, 20);

        assertEquals(0, page.getTotalElements());
        assertEquals(0, page.getTotalPages());
    }

    private Page<Message> conversations(User user, int page, int size) {
        return messageService.getConversations(user.getId(), PageRequest.of(page, size));
    }

    private static List<String> contents(Page<Message> page) {
        return page.getContent().stream().map(Message::getContent).toList();
    }

    // --- Test data, saved straight through the repositories ---

    private User user(String name) {
        User user = new User();
        user.setName(name);
        user.setEmail(name + "@conversations-test.example");
        user.setPassword("not-a-real-hash");
        user.setRole("EMPLOYEE");
        return userRepository.save(user);
    }

    // The save stamps the time (B29), so the order of these calls is the order
    // of the messages. Two saves in the same microsecond still come out in that
    // order: "newest" is the highest id, and the page sorts by id after time.
    private void message(User sender, User receiver, String content) {
        Message message = new Message();
        message.setSender(sender);
        message.setReceiver(receiver);
        message.setContent(content);
        messageRepository.save(message);
    }
}
