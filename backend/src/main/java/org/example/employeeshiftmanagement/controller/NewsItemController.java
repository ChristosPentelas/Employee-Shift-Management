package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.config.CurrentUser;
import org.example.employeeshiftmanagement.dto.CreateNewsRequest;
import org.example.employeeshiftmanagement.dto.NewsItemResponse;
import org.example.employeeshiftmanagement.dto.UpdateNewsRequest;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/news")
public class NewsItemController {

    private final NewsItemService newsItemService;

    public NewsItemController(NewsItemService newsItemService) {
        this.newsItemService = newsItemService;
    }

    @PostMapping
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<NewsItemResponse> createNews(Authentication authentication,
                                       @Valid @RequestBody CreateNewsRequest request) {
        // The author is the supervisor posting it, not an id they send.
        NewsItem item = newsItemService.createNewsItem(
                toNewsItem(request), CurrentUser.id(authentication));
        return new ResponseEntity<>(NewsItemResponse.from(item), HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<NewsItemResponse>> getAllNews() {
        return new ResponseEntity<>(toResponses(newsItemService.getAllNews()), HttpStatus.OK);
    }

    @GetMapping("/type/{type}")
    public ResponseEntity<List<NewsItemResponse>> getAllNewsByType(@PathVariable NewsType type) {
        return new ResponseEntity<>(toResponses(newsItemService.getNewsByType(type)), HttpStatus.OK);
    }

    @GetMapping("/{id}")
    public ResponseEntity<NewsItemResponse> getNewsById(@PathVariable Integer id) {
        return ResponseEntity.ok(NewsItemResponse.from(newsItemService.getNewsItemById(id)));
    }

    @GetMapping("/author/{authorId}")
    public ResponseEntity<List<NewsItemResponse>> getNewsAuthorById(@PathVariable Integer authorId) {
        return ResponseEntity.ok(toResponses(newsItemService.getNewsItemsByAuthor(authorId)));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<NewsItemResponse> update(@PathVariable Integer id,
                                                   @Valid @RequestBody UpdateNewsRequest request) {
        NewsItem updated = newsItemService.updateNewsItem(toNewsDetails(request), id);
        return ResponseEntity.ok(NewsItemResponse.from(updated));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<Void> delete(@PathVariable Integer id) {
        newsItemService.deleteNewsItem(id);
        return new ResponseEntity<>(HttpStatus.NO_CONTENT);
    }

    private static List<NewsItemResponse> toResponses(List<NewsItem> items) {
        return items.stream().map(NewsItemResponse::from).toList();
    }

    private NewsItem toNewsItem(CreateNewsRequest request) {
        NewsItem item = new NewsItem();
        item.setTitle(request.title());
        item.setDescription(request.description());
        item.setType(request.type());
        item.setDeadline(request.deadline());
        item.setTargetValue(request.targetValue());
        return item;
    }

    private NewsItem toNewsDetails(UpdateNewsRequest request) {
        NewsItem item = new NewsItem();
        item.setTitle(request.title());
        item.setDescription(request.description());
        item.setDeadline(request.deadline());
        item.setTargetValue(request.targetValue());
        return item;
    }
}
