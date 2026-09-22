package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.exception.ResourceNotFoundException;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.NewsItemRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

@Service
public class NewsItemService {

    /**
     * Newest first. The id breaks ties between posts with the same createdAt;
     * without a unique last key, the database may order those rows differently
     * on each query, and a post can then appear on two pages or on none.
     */
    private static final Sort NEWEST_FIRST =
            Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id"));

    private final NewsItemRepository newsItemRepository;
    private final UserService userService;

    public NewsItemService(NewsItemRepository newsItemRepository, UserService userService) {
        this.newsItemRepository = newsItemRepository;
        this.userService = userService;
    }

    public NewsItem createNewsItem(NewsItem newsItem, Integer authorId) {
        // The id arrives as a plain Integer instead of wrapped in a half-built
        // NewsItem.author, so a missing author is a clear argument rather than
        // a NullPointerException on getAuthor().getId().
        User author = userService.findUserById(authorId);
        newsItem.setAuthor(author);
        return newsItemRepository.save(newsItem);
    }

    public Page<NewsItem> getAllNews(Pageable pageable) {
        return newsItemRepository.findAll(newestFirst(pageable));
    }

    public Page<NewsItem> getNewsItemsByAuthor(Integer authorId, Pageable pageable) {
        return newsItemRepository.findByAuthorId(authorId, newestFirst(pageable));
    }

    public Page<NewsItem> getNewsByType(NewsType type, Pageable pageable) {
        return newsItemRepository.findByType(type, newestFirst(pageable));
    }

    /**
     * Keeps the page number and size the client asked for, but not its sort:
     * the order is the server's decision. A client-chosen sort could name any
     * entity field, including ones the response never shows.
     */
    private static Pageable newestFirst(Pageable pageable) {
        return PageRequest.of(pageable.getPageNumber(), pageable.getPageSize(), NEWEST_FIRST);
    }

    public NewsItem getNewsItemById(Integer id) {
        return newsItemRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("News item not found"));
    }

    public NewsItem updateNewsItem(NewsItem details,Integer id) {
        NewsItem newsItem = newsItemRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("News item not found"));
        newsItem.setTitle(details.getTitle());
        newsItem.setDescription(details.getDescription());
        newsItem.setDeadline(details.getDeadline());
        newsItem.setTargetValue(details.getTargetValue());

        return newsItemRepository.save(newsItem);
    }

    public void deleteNewsItem(Integer id) {
        if(!newsItemRepository.existsById(id)) {
            throw new ResourceNotFoundException("News item not found");
        }
        newsItemRepository.deleteById(id);
    }


}
