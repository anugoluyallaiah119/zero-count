package com.zerocount.server.player;

import com.zerocount.server.auth.JwtService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Bearer-token guard for protected endpoints (E2.4).
 *
 * Validates the access JWT and exposes the authenticated user id as a request
 * attribute ({@link #ATTR_USER_ID}). Unauthenticated requests get a uniform
 * 401 — no detail about why (standards §3.4).
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {

    public static final String ATTR_USER_ID = "zerocount.userId";

    private final JwtService jwt;

    public AuthInterceptor(JwtService jwt) {
        this.jwt = jwt;
    }

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler)
            throws Exception {
        // Let CORS preflight requests through; browsers do not send Authorization on OPTIONS.
        if ("OPTIONS".equalsIgnoreCase(req.getMethod())) {
            return true;
        }
        String header = req.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                UUID userId = jwt.validateAccessToken(header.substring(7));
                req.setAttribute(ATTR_USER_ID, userId);
                return true;
            } catch (JwtService.InvalidTokenException e) {
                // fall through to 401
            }
        }
        res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        res.setContentType("application/json");
        res.getWriter().write("{\"error\":\"authentication required\"}");
        return false;
    }

    /** Extract the authenticated user id; caller must be behind this interceptor. */
    public static UUID currentUserId(HttpServletRequest req) {
        Object v = req.getAttribute(ATTR_USER_ID);
        if (v instanceof UUID id) return id;
        throw new IllegalStateException("no authenticated user on this request");
    }
}
