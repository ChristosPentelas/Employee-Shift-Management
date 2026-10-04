package org.example.employeeshiftmanagement.model;

import jakarta.persistence.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@NoArgsConstructor
@AllArgsConstructor
@Getter
@Setter

@Entity
@Table(name = "messages")
public class Message {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false)
    private String content;

    @Column(nullable = false)
    private LocalDateTime timestamp = LocalDateTime.now(); //Automatic time recording

    @Column(nullable = false)
    private boolean isRead = false; //To know if the receiver saw it

    // LAZY: each query decides whether it needs the users. The list queries in
    // MessageRepository ask for them with @EntityGraph, so they come in the
    // same SQL statement instead of one extra query per user (F10).
    // CASCADE: deleting either user deletes the message, from both inboxes.
    // MySQL does it, from the foreign keys' ON DELETE rule (V5); these
    // annotations only state the rule here.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id",nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User sender;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "receiver_id",nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User receiver;
}
