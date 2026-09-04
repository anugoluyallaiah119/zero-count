package com.zerocount.server.player;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Registers the Bearer-token guard on all authenticated API namespaces. */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final AuthInterceptor authInterceptor;

    public WebConfig(AuthInterceptor authInterceptor) {
        this.authInterceptor = authInterceptor;
    }

    /**
     * The Flutter web dev server serves the app from a random localhost port,
     * so browser calls to the API are cross-origin. Allow any localhost/127.0.0.1
     * origin for dev; tighten this to the real web domain for production.
     */
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOriginPatterns("http://localhost:*", "http://127.0.0.1:*")
            .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
            .allowedHeaders("*")
            .allowCredentials(true);
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(authInterceptor)
            .addPathPatterns("/api/players/**", "/api/rooms/**",
                "/api/events/**", "/api/analytics/**",
                "/api/wallet/**", "/api/rewards/**", "/api/friends/**",
                "/api/leaderboards/**", "/api/challenges/**",
                "/api/contests/**", "/api/shop/**", "/api/notifications/**",
                "/api/admin/**", "/api/achievements/**");
    }
}
