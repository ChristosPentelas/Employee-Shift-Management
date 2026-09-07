package org.example.employeeshiftmanagement.repository;

import jakarta.transaction.Transactional;
import org.example.employeeshiftmanagement.model.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MessageRepository extends JpaRepository<Message, Integer> {


    List<Message> findByReceiverIdOrderByTimestampDesc(Integer receiverId); //Every message that recieves a user

    List<Message> findBySenderIdOrderByTimestampDesc(Integer senderId); //Every message that send a user

    //Convertation between two users
    List<Message> findBySenderIdAndReceiverIdOrSenderIdAndReceiverIdOrderByTimestampAsc(Integer senderId1, Integer receiverId1,
                                                                                         Integer senderId2,Integer receiverId2);

    List<Message> findByReceiverIdAndIsReadFalse(Integer receiverId);

    @Modifying
    @Transactional
    void deleteBySenderId(Integer senderId);

    @Modifying
    @Transactional
    void deleteByReceiverId(Integer receiverId);
}
