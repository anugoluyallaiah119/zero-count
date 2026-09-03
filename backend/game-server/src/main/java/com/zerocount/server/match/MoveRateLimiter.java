package com.zerocount.server.match;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;

/**
 * Anti-cheat rate limit (M1.5): sliding-window cap on WS commands per user.
 * Legit play is ~1 move per 2s; 12 commands / 10s is generous headroom while
 * making scripted flooding useless. Excess commands are rejected before they
 * reach the engine.
 */
@Component
public class MoveRateLimiter {

    public static final int WINDOW_SECONDS = 10;
    public static final int MAX_COMMANDS = 12;

    private final Map<UUID, Deque<Long>> windows = new ConcurrentHashMap<>();

    /** True if the command is allowed; false when the user is over the cap. */
    public synchronized boolean allow(UUID userId) {
        long now = System.currentTimeMillis();
        long cutoff = now - WINDOW_SECONDS * 1000L;
        Deque<Long> w = windows.computeIfAbsent(userId, k -> new ArrayDeque<>());
        while (!w.isEmpty() && w.peekFirst() < cutoff) {
            w.pollFirst();
        }
        if (w.size() >= MAX_COMMANDS) {
            return false;
        }
        w.addLast(now);
        return true;
    }
}
