package org.example.employeeshiftmanagement.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.example.employeeshiftmanagement.model.User;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Integer> {

    // Custom query to find a user by their unique email
    //We use Optional to handle the case where the User does not exist better, instead of returning null
    Optional<User> findByEmail(String email);
}
