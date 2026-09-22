package org.example.employeeshiftmanagement.repository;

import jakarta.transaction.Transactional;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

@Repository
public interface LeaveRequestRepository extends JpaRepository<LeaveRequest, Integer> {

    // The order travels inside the Pageable, which LeaveRequestService builds (F9).
    // Every list query names the user it returns with @EntityGraph: Hibernate
    // then joins it into the same SELECT. Without it, the user is LAZY and
    // is fetched separately, once per user, when the response is built (F10).

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

    @Modifying
    @Transactional
    void deleteByUserId(Integer userId);
}
