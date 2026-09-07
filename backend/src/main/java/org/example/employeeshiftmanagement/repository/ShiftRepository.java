package org.example.employeeshiftmanagement.repository;

import jakarta.transaction.Transactional;
import org.example.employeeshiftmanagement.model.Shift;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, Integer> {

    List<Shift> findByUserId(Integer userId);

    List<Shift> findByUserIdAndDateBetweenOrderByDateAsc(Integer userId, LocalDate startDate, LocalDate endDate);
    //We implement the schedule, we take the shifts in a specific time period sorted from the closest to the furthest

    @Modifying
    @Transactional
    void deleteByUserId(Integer userId);
}
