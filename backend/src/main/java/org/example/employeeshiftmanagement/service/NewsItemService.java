package org.example.employeeshiftmanagement.service;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.model.User;
import org.example.employeeshiftmanagement.repository.NewsItemRepository;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class NewsItemService {

    private final NewsItemRepository newsItemRepository;
    private final UserService userService;

    public NewsItemService(NewsItemRepository newsItemRepository, UserService userService) {
        this.newsItemRepository = newsItemRepository;
        this.userService = userService;
    }

    public NewsItem createNewsItem(NewsItem newsItem) {
        User author = userService.findUserById(newsItem.getAuthor().getId());
        newsItem.setAuthor(author);
        return newsItemRepository.save(newsItem);
    }

    public List<NewsItem> getAllNews() {
        return newsItemRepository.findAllByOrderByCreatedAtDesc();
    }

    public List<NewsItem> getNewsItemsByAuthor(Integer authorId) {
        return newsItemRepository.findByAuthorIdOrderByCreatedAtDesc(authorId);
    }

    public List<NewsItem> getNewsByType(NewsType type) {
        return newsItemRepository.findByTypeOrderByCreatedAtDesc(type);
    }

    public NewsItem getNewsItemById(Integer id) {
        return newsItemRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("News item not found"));
    }

    public NewsItem updateNewsItem(NewsItem details,Integer id) {
        NewsItem newsItem = newsItemRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("News item not found"));
        newsItem.setTitle(details.getTitle());
        newsItem.setDescription(details.getDescription());
        newsItem.setDeadline(details.getDeadline());
        newsItem.setTargetValue(details.getTargetValue());

        return newsItemRepository.save(newsItem);
    }

    public void deleteNewsItem(Integer id) {
        if(!newsItemRepository.existsById(id)) {
            throw new RuntimeException("News item not found");
        }
        newsItemRepository.deleteById(id);
    }


}
