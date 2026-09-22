package org.example.employeeshiftmanagement.repository;

import jakarta.transaction.Transactional;
import org.example.employeeshiftmanagement.model.LeaveRequest;
import org.example.employeeshiftmanagement.model.LeaveStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.stereotype.Repository;

@Repository
public interface LeaveRequestRepository extends JpaRepository<LeaveRequest, Integer> {

    // Everyone's requests: findAll(Pageable), inherited from JpaRepository.
    // The order travels inside the Pageable, which LeaveRequestService builds (F9).
    Page<LeaveRequest> findByUserId(Integer userId, Pageable pageable);
    Page<LeaveRequest> findByStatus(LeaveStatus status, Pageable pageable);
    Page<LeaveRequest> findByUserIdAndStatus(Integer userId, LeaveStatus status, Pageable pageable);

    @Modifying
    @Transactional
    void deleteByUserId(Integer userId);
}
