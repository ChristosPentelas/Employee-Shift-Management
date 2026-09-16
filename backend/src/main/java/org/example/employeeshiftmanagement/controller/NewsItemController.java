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
    public ResponseEntity<?> createNews(Authentication authentication,
                                       @Valid @RequestBody CreateNewsRequest request) {
        try{
            // The author is the supervisor posting it, not an id they send.
            NewsItem item = newsItemService.createNewsItem(
                    toNewsItem(request), CurrentUser.id(authentication));
            return new ResponseEntity<>(NewsItemResponse.from(item), HttpStatus.CREATED);
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
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
    public ResponseEntity<?> getNewsById(@PathVariable Integer id) {
        try{
            NewsItem item = newsItemService.getNewsItemById(id);
            return new ResponseEntity<>(NewsItemResponse.from(item), HttpStatus.OK);
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping("/author/{authorId}")
    public ResponseEntity<?> getNewsAuthorById(@PathVariable Integer authorId) {
        return new ResponseEntity<>(toResponses(newsItemService.getNewsItemsByAuthor(authorId)), HttpStatus.OK);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<?> update(@PathVariable Integer id, @Valid @RequestBody UpdateNewsRequest request) {
        try{
            NewsItem updated = newsItemService.updateNewsItem(toNewsDetails(request), id);
            return ResponseEntity.ok(NewsItemResponse.from(updated));
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPERVISOR')")
    public ResponseEntity<?> delete(@PathVariable Integer id) {
        try{
            newsItemService.deleteNewsItem(id);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
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
