package org.example.employeeshiftmanagement.repository;

import jakarta.transaction.Transactional;
import org.example.employeeshiftmanagement.model.Message;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

@Repository
public interface MessageRepository extends JpaRepository<Message, Integer> {

    // The order travels inside the Pageable, which MessageService builds (F9).

    Page<Message> findByReceiverId(Integer receiverId, Pageable pageable); //Every message that recieves a user

    Page<Message> findBySenderId(Integer senderId, Pageable pageable); //Every message that send a user

    //Convertation between two users
    Page<Message> findBySenderIdAndReceiverIdOrSenderIdAndReceiverId(Integer senderId1, Integer receiverId1,
                                                                     Integer senderId2, Integer receiverId2,
                                                                     Pageable pageable);

    Page<Message> findByReceiverIdAndIsReadFalse(Integer receiverId, Pageable pageable);

    @Modifying
    @Transactional
    void deleteBySenderId(Integer senderId);

    @Modifying
    @Transactional
    void deleteByReceiverId(Integer receiverId);
}
