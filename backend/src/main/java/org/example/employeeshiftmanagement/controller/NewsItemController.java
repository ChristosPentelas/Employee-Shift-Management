package org.example.employeeshiftmanagement.controller;

import jakarta.validation.Valid;
import org.example.employeeshiftmanagement.config.CurrentUser;
import org.example.employeeshiftmanagement.dto.CreateNewsRequest;
import org.example.employeeshiftmanagement.dto.NewsItemResponse;
import org.example.employeeshiftmanagement.dto.PageResponse;
import org.example.employeeshiftmanagement.dto.UpdateNewsRequest;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

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

    /**
     * One page, newest first: {@code ?page=0&size=20}. Both are optional
     * (defaults 0 and 20), and a size above 100 is lowered to 100 - see
     * spring.data.web.pageable.* in application.properties. A {@code sort}
     * parameter is accepted but ignored; the service fixes the order (F9).
     *
     * {@code ?type=GOAL} keeps only posts of that type. Optional, like every
     * list filter (B49): no type, or an empty one, is every post. A word that
     * is not a NewsType is a 400, before this method runs. It replaced
     * /news/type/{type}; /news/author/{authorId} went with it, unused.
     */
    @GetMapping
    public ResponseEntity<PageResponse<NewsItemResponse>> getAllNews(@RequestParam(required = false) NewsType type,
                                                                     Pageable pageable) {
        Page<NewsItem> news = type == null
                ? newsItemService.getAllNews(pageable)
                : newsItemService.getNewsByType(type, pageable);
        return ResponseEntity.ok(PageResponse.from(news, NewsItemResponse::from));
    }

    @GetMapping("/{id}")
    public ResponseEntity<NewsItemResponse> getNewsById(@PathVariable Integer id) {
        return ResponseEntity.ok(NewsItemResponse.from(newsItemService.getNewsItemById(id)));
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
        return ResponseEntity.noContent().build();
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
