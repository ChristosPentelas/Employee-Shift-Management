package org.example.employeeshiftmanagement.repository;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NewsItemRepository extends JpaRepository<NewsItem, Integer> {

    List<NewsItem> findAllByOrderByCreatedAtDesc(); //It brings all the news sorted by the most recent

    List<NewsItem> findByTypeOrderByCreatedAtDesc(NewsType type); //It brings news of a specific type

    List<NewsItem> findByAuthorIdOrderByCreatedAtDesc(Integer authorId); //It brings news from a creator
}
