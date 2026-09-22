package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.config.SecurityConfig;
import org.example.employeeshiftmanagement.controller.NewsItemController;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(value = NewsItemController.class, properties = TestProperties.JWT_SECRET_PROPERTY)
@Import({SecurityConfig.class, JwtConfig.class})
class NewsItemControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private NewsItemService newsItemService;

    private static NewsItem newsItem() {
        NewsItem item = new NewsItem();
        item.setId(1);
        item.setTitle("Staff meeting");
        item.setDescription("Monday 09:00");
        item.setType(NewsType.ANNOUNCEMENT);
        item.setAuthor(TestUsers.supervisor());
        return item;
    }

    /** What the service hands back: one item, as page 0 of a 20-row page. */
    private static Page<NewsItem> onePage() {
        return new PageImpl<>(List.of(newsItem()), PageRequest.of(0, 20), 1);
    }

    /** The Pageable the controller passed on to the service for GET /news. */
    private Pageable pageableSentToService() {
        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(newsItemService).getAllNews(captor.capture());
        return captor.getValue();
    }

    @Test
    void theNewsFeedDoesNotLeakTheAuthorsPassword() throws Exception {
        when(newsItemService.getAllNews(any(Pageable.class))).thenReturn(onePage());

        // Everyone reads the news, so an employee token on purpose.
        mockMvc.perform(get("/api/v1/news").with(TestTokens.employee()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("Staff meeting"))
                .andExpect(jsonPath("$.content[0].author.name").value("Boss"))
                .andExpect(jsonPath("$.content[0].author.password").doesNotExist());
    }

    @Test
    void theNewsFeedIsOnePageWithItsPosition() throws Exception {
        when(newsItemService.getAllNews(any(Pageable.class))).thenReturn(
                new PageImpl<>(List.of(newsItem()), PageRequest.of(2, 1), 5));

        mockMvc.perform(get("/api/v1/news?page=2&size=1").with(TestTokens.employee()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.page").value(2))
                .andExpect(jsonPath("$.size").value(1))
                .andExpect(jsonPath("$.totalElements").value(5))
                .andExpect(jsonPath("$.totalPages").value(5));
    }

    @Test
    void withoutPageParametersTheFirstTwentyAreAskedFor() throws Exception {
        when(newsItemService.getAllNews(any(Pageable.class))).thenReturn(onePage());

        mockMvc.perform(get("/api/v1/news").with(TestTokens.employee()))
                .andExpect(status().isOk());

        Pageable asked = pageableSentToService();
        assertEquals(0, asked.getPageNumber());
        assertEquals(20, asked.getPageSize());
    }

    @Test
    void aHugePageSizeIsLoweredToTheCap() throws Exception {
        when(newsItemService.getAllNews(any(Pageable.class))).thenReturn(onePage());

        // Without the cap, ?size= is the "no pagination" switch F9 is about.
        mockMvc.perform(get("/api/v1/news?size=100000").with(TestTokens.employee()))
                .andExpect(status().isOk());

        assertEquals(100, pageableSentToService().getPageSize());
    }

    @Test
    void theNewsAuthorIsTheCallerNotTheAuthorIdSent() throws Exception {
        when(newsItemService.createNewsItem(any(NewsItem.class), any())).thenReturn(newsItem());

        mockMvc.perform(post("/api/v1/news")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Staff meeting","description":"Monday 09:00",
                                 "type":"ANNOUNCEMENT","authorId":99}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.author.password").doesNotExist());

        // Written by the caller (supervisor 9), not by the authorId 99 in the body.
        verify(newsItemService).createNewsItem(any(NewsItem.class), eq(9));
    }

    @Test
    void creatingNewsRejectsABlankTitle() throws Exception {
        mockMvc.perform(post("/api/v1/news")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"","description":"Monday 09:00",
                                 "type":"ANNOUNCEMENT","authorId":7}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void creatingNewsRejectsATitleLongerThanTheColumn() throws Exception {
        mockMvc.perform(post("/api/v1/news")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"%s","description":"Monday 09:00","type":"ANNOUNCEMENT"}
                                """.formatted("a".repeat(256))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.title")
                        .value("Title must be at most 255 characters"));

        verify(newsItemService, never()).createNewsItem(any(), anyInt());
    }

    @Test
    void updatingNewsRejectsADescriptionLongerThanTheColumn() throws Exception {
        mockMvc.perform(put("/api/v1/news/1")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Meeting","description":"%s"}
                                """.formatted("a".repeat(256))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.description")
                        .value("Description must be at most 255 characters"));

        verify(newsItemService, never()).updateNewsItem(any(), anyInt());
    }

    @Test
    void theNewsFeedWithoutATokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/news"))
                .andExpect(status().isUnauthorized());

        verify(newsItemService, never()).getAllNews(any());
    }

    @Test
    void anEmployeeCannotPostNews() throws Exception {
        mockMvc.perform(post("/api/v1/news")
                        .with(TestTokens.employee())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Staff meeting","description":"Monday 09:00",
                                 "type":"ANNOUNCEMENT","authorId":7}
                                """))
                .andExpect(status().isForbidden());

        verify(newsItemService, never()).createNewsItem(any(), any());
    }

    @Test
    void anEmployeeCannotDeleteNews() throws Exception {
        mockMvc.perform(delete("/api/v1/news/1").with(TestTokens.employee()))
                .andExpect(status().isForbidden());

        verify(newsItemService, never()).deleteNewsItem(anyInt());
    }

    @Test
    void postingNewsThatBlowsUpIsAServerErrorNotANotFound() throws Exception {
        // The audit's own example: NewsItemService.createNewsItem dereferences
        // the author without a null check. createNews used to catch Exception
        // and report that NPE as "404 not found" (F14).
        when(newsItemService.createNewsItem(any(NewsItem.class), any()))
                .thenThrow(new NullPointerException());

        mockMvc.perform(post("/api/v1/news")
                        .with(TestTokens.supervisor())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Staff meeting","description":"Monday 09:00",
                                 "type":"ANNOUNCEMENT"}
                                """))
                .andExpect(status().isInternalServerError());
    }

    @Test
    void aBugInsideTheServerIsAServerErrorAndLeaksNothing() throws Exception {
        when(newsItemService.getAllNews(any(Pageable.class)))
                .thenThrow(new NullPointerException("author is null in news_items"));

        mockMvc.perform(get("/api/v1/news").with(TestTokens.employee()))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.status").value(500))
                // The exception text names a table; it belongs in the log, not
                // in an answer sent to a phone (F14).
                .andExpect(jsonPath("$.detail").value("Something went wrong"));
    }
}
