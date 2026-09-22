package org.example.employeeshiftmanagement.repository;

import jakarta.transaction.Transactional;
import org.example.employeeshiftmanagement.model.Message;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

@Repository
public interface MessageRepository extends JpaRepository<Message, Integer> {

    // The order travels inside the Pageable, which MessageService builds (F9).
    // Every list query names the users it returns with @EntityGraph: Hibernate
    // then joins them into the same SELECT. Without it, the users are LAZY and
    // each one would be fetched separately when the response is built (F10).

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findByReceiverId(Integer receiverId, Pageable pageable); //Every message that recieves a user

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findBySenderId(Integer senderId, Pageable pageable); //Every message that send a user

    //Convertation between two users
    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findBySenderIdAndReceiverIdOrSenderIdAndReceiverId(Integer senderId1, Integer receiverId1,
                                                                     Integer senderId2, Integer receiverId2,
                                                                     Pageable pageable);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    Page<Message> findByReceiverIdAndIsReadFalse(Integer receiverId, Pageable pageable);

    @Modifying
    @Transactional
    void deleteBySenderId(Integer senderId);

    @Modifying
    @Transactional
    void deleteByReceiverId(Integer receiverId);
}
