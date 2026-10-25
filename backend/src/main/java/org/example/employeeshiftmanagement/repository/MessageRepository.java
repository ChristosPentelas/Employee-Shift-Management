package org.example.employeeshiftmanagement.repository;

import org.example.employeeshiftmanagement.model.Message;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface MessageRepository extends JpaRepository<Message, Integer> {

    // The order travels inside the Pageable, which MessageService builds (F9).
    // Every query whose messages reach a response names the users with
    // @EntityGraph: Hibernate then joins them into the same SELECT. Without
    // it, the users are LAZY and not loaded, and building the response throws
    // LazyInitializationException, since the session has already closed (B28).

    // One message: markAsRead returns it, so its users are needed. Inherited
    // from JpaRepository; declared again only to attach the entity graph.
    @EntityGraph(attributePaths = {"sender", "receiver"})
    @Override
    Optional<Message> findById(Integer id);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findByReceiverId(Integer receiverId, Pageable pageable); //Every message a user receives

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findBySenderId(Integer senderId, Pageable pageable); //Every message a user sends

    //Conversation between two users
    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findBySenderIdAndReceiverIdOrSenderIdAndReceiverId(Integer senderId1, Integer receiverId1,
                                                                     Integer senderId2, Integer receiverId2,
                                                                     Pageable pageable);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findByReceiverIdAndIsReadFalse(Integer receiverId, Pageable pageable);

    // One row per person the user has messaged or been messaged by: the newest
    // message between them, whoever sent it (B26). The CASE is "the other
    // person"; for a message to yourself both sides are you, so those group
    // into one row as well.
    //
    // Newest is the highest id, not the latest timestamp: ids never repeat, so
    // each group keeps exactly one message, where two messages in the same
    // millisecond would both match a max(timestamp). Ids follow the order the
    // rows were inserted; the timestamp is taken just before the INSERT (B29),
    // so when two sends race, a few microseconds apart, this row's message and
    // the chat's last one could still differ.
    //
    // The page's count query is the one Spring writes from this (select
    // count(m), same WHERE), which counts conversations, not messages:
    // ConversationsIntegrationTest checks it, so no hand-written copy of the
    // query is kept in step with this one. No ORDER BY here: it comes with the
    // Pageable.
    @EntityGraph(attributePaths = {"sender", "receiver"})
    @Query("""
            select m from Message m
            where m.id in (
                select max(m2.id) from Message m2
                where m2.sender.id = :userId or m2.receiver.id = :userId
                group by case when m2.sender.id = :userId then m2.receiver.id else m2.sender.id end
            )
            """)
    Page<Message> findLatestPerConversation(@Param("userId") Integer userId, Pageable pageable);

    // One update for a whole chat and the return value is the number of rows changed.
    @Modifying
    @Query("""
            update Message m set m.isRead = true 
            where m.sender.id = :senderId and m.receiver.id = :receiverId 
          and m.isRead = false
            """)
    int markChatAsRead(@Param("senderId") Integer senderId, @Param("receiverId") Integer receiverId);
}
