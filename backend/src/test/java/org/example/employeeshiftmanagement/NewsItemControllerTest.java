package org.example.employeeshiftmanagement;

import org.example.employeeshiftmanagement.config.JwtConfig;
import org.example.employeeshiftmanagement.config.SecurityConfig;
import org.example.employeeshiftmanagement.controller.NewsItemController;
import org.example.employeeshiftmanagement.model.NewsItem;
import org.example.employeeshiftmanagement.model.NewsType;
import org.example.employeeshiftmanagement.service.NewsItemService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

    @Test
    void theNewsFeedDoesNotLeakTheAuthorsPassword() throws Exception {
        when(newsItemService.getAllNews()).thenReturn(List.of(newsItem()));

        mockMvc.perform(get("/api/v1/news").with(jwt()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].title").value("Staff meeting"))
                .andExpect(jsonPath("$[0].author.name").value("Boss"))
                .andExpect(jsonPath("$[0].author.password").doesNotExist());
    }

    @Test
    void creatingNewsTakesAFlatAuthorIdAndDoesNotLeakThePassword() throws Exception {
        when(newsItemService.createNewsItem(any(NewsItem.class), any())).thenReturn(newsItem());

        mockMvc.perform(post("/api/v1/news")
                        .with(jwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"Staff meeting","description":"Monday 09:00",
                                 "type":"ANNOUNCEMENT","authorId":7}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.author.password").doesNotExist());

        verify(newsItemService).createNewsItem(any(NewsItem.class), eq(7));
    }

    @Test
    void creatingNewsRejectsABlankTitle() throws Exception {
        mockMvc.perform(post("/api/v1/news")
                        .with(jwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"","description":"Monday 09:00",
                                 "type":"ANNOUNCEMENT","authorId":7}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void theNewsFeedWithoutATokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/api/v1/news"))
                .andExpect(status().isUnauthorized());

        verify(newsItemService, never()).getAllNews();
    }
}
