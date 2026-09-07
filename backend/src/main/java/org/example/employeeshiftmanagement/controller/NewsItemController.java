package org.example.employeeshiftmanagement.controller;

import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
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
    public ResponseEntity<?> createNews(@RequestBody NewsItem newsItem) {
        try{
            NewsItem item = newsItemService.createNewsItem(newsItem);
            return new ResponseEntity<>(item, HttpStatus.CREATED);
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping
    public ResponseEntity<List<NewsItem>> getAllNews() {
        List<NewsItem> newsItems = newsItemService.getAllNews();
        return new ResponseEntity<>(newsItems, HttpStatus.OK);
    }

    @GetMapping("/type/{type}")
    public ResponseEntity<List<NewsItem>> getAllNewsByType(@PathVariable NewsType type) {
        List<NewsItem> newsItems = newsItemService.getNewsByType(type);
        return new ResponseEntity<>(newsItems, HttpStatus.OK);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getNewsById(@PathVariable Integer id) {
        try{
            NewsItem item = newsItemService.getNewsItemById(id);
            return new ResponseEntity<>(item, HttpStatus.OK);
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @GetMapping("/author/{authorId}")
    public ResponseEntity<?> getNewsAuthorById(@PathVariable Integer authorId) {
        List<NewsItem> newsItems = newsItemService.getNewsItemsByAuthor(authorId);
        return new ResponseEntity<>(newsItems, HttpStatus.OK);
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Integer id, @RequestBody NewsItem newsItem) {
        try{
            return ResponseEntity.ok(newsItemService.updateNewsItem(newsItem,id));
        }catch(Exception e){
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable Integer id) {
        try{
            newsItemService.deleteNewsItem(id);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(e.getMessage());
        }
    }

}
