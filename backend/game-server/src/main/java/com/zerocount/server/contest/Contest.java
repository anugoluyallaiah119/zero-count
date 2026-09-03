package com.zerocount.server.contest;

import java.time.Instant;
import java.util.UUID;

/** A scheduled competition (monthly challenge, seasonal event). */
public record Contest(
        UUID id,
        String title,
        String rulesJson,
        Instant startsAt,
        Instant endsAt) {

    public Contest {
        if (title == null || title.isBlank())
            throw new IllegalArgumentException("title is required");
        if (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt))
            throw new IllegalArgumentException("endsAt must be after startsAt");
    }

    public boolean isLive(Instant now) {
        return !now.isBefore(startsAt) && now.isBefore(endsAt);
    }
}
