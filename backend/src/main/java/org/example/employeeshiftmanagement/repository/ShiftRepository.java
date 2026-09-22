package org.example.employeeshiftmanagement.repository;

import jakarta.transaction.Transactional;
import org.example.employeeshiftmanagement.model.Shift;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, Integer> {

    Page<Shift> findByUserId(Integer userId, Pageable pageable);

    // The calendars: every shift in a date range (both days included), in the
    // order ShiftService passes. Not paged - the range itself is the limit,
    // capped by ValidDateRange (F9).
    List<Shift> findByDateBetween(LocalDate startDate, LocalDate endDate, Sort sort);

    List<Shift> findByUserIdAndDateBetween(Integer userId, LocalDate startDate, LocalDate endDate, Sort sort);
    //We implement the schedule, we take the shifts in a specific time period

    @Modifying
    @Transactional
    void deleteByUserId(Integer userId);
}
