package org.example.employeeshiftmanagement.repository;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface NewsItemRepository extends JpaRepository<NewsItem, Integer> {

    // The order is not in the method names - it travels inside the
    // Pageable, which NewsItemService builds (F9).
    // Every query whose posts reach a response names the author with
    // @EntityGraph: Hibernate then joins it into the same SELECT. Without it,
    // the author is LAZY and not loaded, and building the response throws
    // LazyInitializationException, since the session has already closed (B28).

    // One post: GET and PUT /news/{id} return it. Inherited from
    // JpaRepository; declared again only to attach the entity graph.
    @EntityGraph(attributePaths = "author")
    @Override
    Optional<NewsItem> findById(Integer id);

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
