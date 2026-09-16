package org.example.employeeshiftmanagement.config;

import org.example.employeeshiftmanagement.exception.ProblemDetailAccessDeniedHandler;
import org.example.employeeshiftmanagement.exception.ProblemDetailAuthenticationEntryPoint;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import tools.jackson.databind.ObjectMapper;

/**
 * Two layers of rules:
 *
 * 1. Here, for every request: who you are. Everything except login and /error
 *    needs a valid token; otherwise 401.
 * 2. On controller methods, with @PreAuthorize: what you may do. Supervisor-only
 *    endpoints answer 403 to anyone else. @EnableMethodSecurity switches those
 *    annotations on; without it they would be silently ignored.
 *
 * Both answers are produced here in the filter chain, which runs before the
 * DispatcherServlet - so ApiExceptionHandler cannot reach them and they need
 * their own handlers to get the same JSON body as every other error (F14).
 */
@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           JwtAuthenticationConverter jwtAuthenticationConverter,
                                           AuthenticationEntryPoint authenticationEntryPoint,
                                           AccessDeniedHandler accessDeniedHandler) throws Exception {
        http
                // CSRF works by making a browser send its cookies to our site
                // without the user noticing. This API authenticates with an
                // Authorization header, which nothing sends automatically, so
                // there is nothing for CSRF to abuse.
                .csrf(csrf -> csrf.disable())
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.POST, "/api/v1/users/login").permitAll()
                        // Spring forwards failed requests (e.g. validation errors) to
                        // /error to build the response. If /error needed a token, an
                        // anonymous caller would see 401 instead of the real 400.
                        .requestMatchers("/error").permitAll()
                        .anyRequest().authenticated())
                // Reads "Authorization: Bearer <token>", checks its signature and
                // expiry with the JwtDecoder from JwtConfig, and turns its role
                // claim into ROLE_... authorities for @PreAuthorize.
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter))
                        // A token that was sent but rejected fails inside the
                        // bearer-token filter, which uses these two.
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                // A request with no token at all, or one refused by @PreAuthorize,
                // never reaches that filter's handlers - it is stopped later, by
                // ExceptionTranslationFilter, which uses these. Both paths have to
                // be set or half the 401s come back with an empty body.
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                // Each request proves itself with its own token; the server keeps
                // no login session between requests.
                .sessionManagement(session -> session
                        .sessionCreationPolicy(SessionCreationPolicy.STATELESS));
        return http.build();
    }

    /**
     * Declared as beans so the filter chain above receives them ready-made, and
     * so a test can replace them without rewriting the chain.
     */
    @Bean
    public AuthenticationEntryPoint authenticationEntryPoint(ObjectMapper objectMapper) {
        return new ProblemDetailAuthenticationEntryPoint(objectMapper);
    }

    @Bean
    public AccessDeniedHandler accessDeniedHandler(ObjectMapper objectMapper) {
        return new ProblemDetailAccessDeniedHandler(objectMapper);
    }

    /**
     * BCrypt hashes a password with a random salt built into the hash, so two
     * users with the same password get different stored values, and it is
     * deliberately slow (~100ms) to make mass guessing impractical.
     *
     * Declared as PasswordEncoder rather than BCryptPasswordEncoder so callers
     * depend on the interface: swapping the algorithm later changes this method
     * only.
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
