package org.example.employeeshiftmanagement.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable()) // Disable CSRF for testing with Postman
                .authorizeHttpRequests(auth -> auth
                        .anyRequest().permitAll() // Allow all requests without login
                );
        return http.build();
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
