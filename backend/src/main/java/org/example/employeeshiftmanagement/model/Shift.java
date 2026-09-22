package org.example.employeeshiftmanagement.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDate;
import java.time.LocalTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor

@Entity
@Table(name="shifts")
public class Shift {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false)
    private LocalDate date;//We use LocalDate to store only day/month/year

    @Column(nullable = false)
    private LocalTime startTime;//Separating the date from the time makes the code more readable.

    @Column(nullable = false)
    private LocalTime endTime;

    @Column(nullable = false)
    private String position;

    // LAZY: each query decides whether it needs the user. The list queries in
    // ShiftRepository ask for it with @EntityGraph, so it comes in the
    // same SQL statement instead of one extra query per user (F10).
    @ManyToOne(fetch = FetchType.LAZY)//Many shifts belong to one user
    @JoinColumn(name="user_id",nullable = false)//We create the foreign key for the users in shifts table
    private User user;

}
