package com.zerocount.server.notification;

import java.util.Map;
import java.util.UUID;

/** An outbound notification to one user. */
public record Notification(
        Kind kind,
        String title,
        String body,
        Map<String, String> data) {

    public enum Kind {
        FRIEND_REQUEST,        // V2.3
        CHALLENGE_NUDGE,       // V2.3 daily challenge reminder (respectful caps)
        STREAK_AT_RISK,        // V2.3
        CONTEST_STARTING,      // V2.5
        REWARD_GRANTED         // V2.4
    }

    public Notification {
        if (kind == null) throw new IllegalArgumentException("kind is required");
        if (title == null || title.isBlank())
            throw new IllegalArgumentException("title is required");
        data = data == null ? Map.of() : Map.copyOf(data);
    }
}
