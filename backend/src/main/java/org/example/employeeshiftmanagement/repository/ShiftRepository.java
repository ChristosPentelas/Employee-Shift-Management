package org.example.employeeshiftmanagement.repository;


import org.example.employeeshiftmanagement.model.Shift;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, Integer> {

    // Every list query names the user it returns with @EntityGraph: Hibernate
    // then joins it into the same SELECT. Without it, the user is LAZY and
    // not loaded, and building the response throws LazyInitializationException,
    // since the session has already closed (B28). findById needs none: see
    // ShiftService.updateShift.

    @EntityGraph(attributePaths = "user")
    Page<Shift> findByUserId(Integer userId, Pageable pageable);

    // The calendars: every shift in a date range (both days included), in the
    // order ShiftService passes. Not paged - the range itself is the limit,
    // capped by ValidDateRange (F9).
    @EntityGraph(attributePaths = "user")
    List<Shift> findByDateBetween(LocalDate startDate, LocalDate endDate, Sort sort);

    @EntityGraph(attributePaths = "user")
    List<Shift> findByUserIdAndDateBetween(Integer userId, LocalDate startDate, LocalDate endDate, Sort sort);
    //We implement the schedule, we take the shifts in a specific time period

    // One DELETE statement, answering how many rows it removed (B31). Written
    // out because a derived delete loads every row and deletes them one by
    // one (measured in F12).
    // A bulk delete goes straight to MySQL, past Hibernate's first-level
    // cache: a shift already loaded in the same transaction would still look
    // stored. Its caller loads none; one that does needs
    // @Modifying(clearAutomatically = true).
    @Modifying
    @Query("delete from Shift s where s.user.id = :userId and s.date between :start and :end")
    int deleteByUserIdAndDateBetween(@Param("userId") Integer userId,
                                     @Param("start") LocalDate start, @Param("end") LocalDate end);
}
