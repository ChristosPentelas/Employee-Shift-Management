package org.example.employeeshiftmanagement.repository;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface NewsItemRepository extends JpaRepository<NewsItem, Integer> {

    // The order is not in the method names - it travels inside the
    // Pageable, which NewsItemService builds (F9).
    // Every list query names the author it returns with @EntityGraph: Hibernate
    // then joins it into the same SELECT. Without it, the author is LAZY and
    // is fetched separately, once per author, when the response is built (F10).

    // All news, one page at a time. Inherited from JpaRepository; declared
    // again only to attach the entity graph.
    @EntityGraph(attributePaths = "author")
    @Override
    Page<NewsItem> findAll(Pageable pageable);

    @EntityGraph(attributePaths = "author")
    Page<NewsItem> findByType(NewsType type, Pageable pageable); //It brings news of a specific type

    @EntityGraph(attributePaths = "author")
    Page<NewsItem> findByAuthorId(Integer authorId, Pageable pageable); //It brings news from a creator
}
