package org.example.employeeshiftmanagement.repository;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface NewsItemRepository extends JpaRepository<NewsItem, Integer> {

    // All news, one page at a time: findAll(Pageable) is inherited from JpaRepository.
    // The order is no longer in the method names - it travels inside the
    // Pageable, which NewsItemService builds (F9).

    Page<NewsItem> findByType(NewsType type, Pageable pageable); //It brings news of a specific type

    Page<NewsItem> findByAuthorId(Integer authorId, Pageable pageable); //It brings news from a creator
}
