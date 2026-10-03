package org.example.employeeshiftmanagement.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.stereotype.Repository;
import org.example.employeeshiftmanagement.model.User;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Integer> {

    // Custom query to find a user by their unique email
    //We use Optional to handle the case where the User does not exist better, instead of returning null
    Optional<User> findByEmail(String email);

    // Derived query: Spring Data reads the method name and generates
    // "select count(*) > 0 from users where role = ?"
    boolean existsByRole(String role);

    // "select ... from users where id = ? for update". Spring Data ignores the
    // word between "find" and "By", so "Locked" is only there for the reader;
    // the lock comes from @Lock. PESSIMISTIC_WRITE, not _READ: a READ lock is
    // "for share", and two of those do not block each other.
    // Kept apart from findById on purpose: every other user lookup must stay
    // lock-free.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<User> findLockedById(Integer id);
}
