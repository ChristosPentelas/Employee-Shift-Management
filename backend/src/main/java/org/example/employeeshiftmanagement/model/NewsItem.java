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
@Table(name = "news_items")
public class NewsItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private NewsType type;

    // Set once, by onCreate() just before the INSERT. updatable = false leaves
    // the column out of every UPDATE, so no later save can rewrite it (B25).
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }

    private LocalDateTime deadline; //For Tasks
    private Integer targetValue; //For Goals

    // LAZY: each query decides whether it needs the author. The list queries in
    // NewsItemRepository ask for it with @EntityGraph, so it comes in the
    // same SQL statement instead of one extra query per user (F10).
    // SET_NULL: deleting the author keeps the post, with no author (B7). MySQL
    // does it, from the foreign key's ON DELETE rule (V5); this annotation only
    // states the rule here.
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id")
    @OnDelete(action = OnDeleteAction.SET_NULL)
    private User author;

}
