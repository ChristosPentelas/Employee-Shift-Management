package org.example.employeeshiftmanagement.repository;

import jakarta.persistence.LockModeType;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Optional;

@Repository
public interface LeaveRequestRepository extends JpaRepository<LeaveRequest, Integer> {

    // The order travels inside the Pageable, which LeaveRequestService builds (F9).
    // Every query whose requests reach a response names the user with
    // @EntityGraph: Hibernate then joins it into the same SELECT. Without it,
    // the user is LAZY and not loaded, and building the response throws
    // LazyInitializationException, since the session has already closed (B28).

    // Everyone's requests. Inherited from JpaRepository; declared again only
    // to attach the entity graph.
    @EntityGraph(attributePaths = "user")
    @Override
    Page<LeaveRequest> findAll(Pageable pageable);

    @EntityGraph(attributePaths = "user")
    Page<LeaveRequest> findByUserId(Integer userId, Pageable pageable);

    @EntityGraph(attributePaths = "user")
    Page<LeaveRequest> findByStatus(LeaveStatus status, Pageable pageable);

    @EntityGraph(attributePaths = "user")
    Page<LeaveRequest> findByUserIdAndStatus(Integer userId, LeaveStatus status, Pageable pageable);

    // "select ... from leave_requests where id = ? for update", as
    // UserRepository.findLockedById: two supervisors deciding the same request
    // at once take turns, so the second sees the first's answer (B63).
    // The answer returns the request, so the user is joined in too. Only the
    // request's row is locked: Hibernate writes "for update of <its alias>",
    // so the employee's users row, which ShiftService locks, stays free.
    @EntityGraph(attributePaths = "user")
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<LeaveRequest> findLockedById(Integer id);

    // Whether one of the user's requests with this status includes the date.
    // "between" includes both ends, so the first and the last day of a leave
    // count (B31). Written out rather than derived: the derived name would be
    // existsByUserIdAndStatusAndStartDateLessThanEqualAndEndDateGreaterThanEqual.
    @Query("""
            select count(l) > 0 from LeaveRequest l
            where l.user.id = :userId and l.status = :status
              and :date between l.startDate and l.endDate
            """)
    boolean existsCovering(@Param("userId") Integer userId, @Param("status") LeaveStatus status,
                           @Param("date") LocalDate date);
}
