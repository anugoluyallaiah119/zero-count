package com.zerocount.server.player;

import com.zerocount.engine.session.AdaptiveDrawParams;
import com.zerocount.engine.session.DrawBrain;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

/**
 * V2.2 Phase 4 — adaptive retention engine.
 *
 * Reads a player's Phase 3 {@link PlayerModelService.Snapshot} and returns
 * per-user {@link AdaptiveDrawParams} that tune {@link DrawBrain} to keep
 * that specific user engaged for more matches. The rules are intentionally
 * conservative — soft nudges only, never guarantees — so competitive
 * integrity is preserved.
 *
 * <h4>Adaptation rules</h4>
 * <ul>
 *   <li><b>New user</b> ({@code matches_played < 5}):
 *       {@code openingBalancerChance = 0.90} so the first few matches feel
 *       actionable.</li>
 *   <li><b>Frustrated</b> ({@code dry_draw_rate > 0.35}):
 *       {@code dryPityMultiplier = 1.5} — soft pity kicks in faster.</li>
 *   <li><b>Weak</b> ({@code avg_show_count > 15}):
 *       {@code dryPityMultiplier = max(current, 1.3)}, opening balancer up to 0.85.</li>
 *   <li><b>Strong</b> ({@code avg_show_count < 6, matches_played >= 20}):
 *       shrink look-ahead to 5, drop pity multiplier to 0.7 — less handholding.</li>
 *   <li><b>Ignoring Special</b> ({@code special_usage_rate < 0.3}):
 *       {@code specialUtilityBoost = 10} — makes the pair-completion picks pop.</li>
 * </ul>
 *
 * Results are cached per user with a short TTL to avoid re-hitting the DB
 * on every draw of a fast match.
 */
@Service
public class AdaptiveDrawService {

    static final long CACHE_TTL_MS = 60_000L;

    private final PlayerModelService models;
    private final ConcurrentHashMap<UUID, Cached> cache = new ConcurrentHashMap<>();

    public AdaptiveDrawService(PlayerModelService models) {
        this.models = models;
    }

    /** Per-user DrawBrain params. Never null; falls back to {@link AdaptiveDrawParams#DEFAULTS}. */
    public AdaptiveDrawParams paramsFor(UUID userId) {
        if (userId == null) return AdaptiveDrawParams.DEFAULTS;
        Cached c = cache.get(userId);
        long now = System.currentTimeMillis();
        if (c != null && now - c.at < CACHE_TTL_MS) return c.params;
        AdaptiveDrawParams p = compute(models.snapshot(userId));
        cache.put(userId, new Cached(p, now));
        return p;
    }

    /** Invalidate any cached entry — call after a match to refresh next time. */
    public void invalidate(UUID userId) {
        if (userId != null) cache.remove(userId);
    }

    /** Pure function: player snapshot → tuned params. Unit-testable. */
    static AdaptiveDrawParams compute(PlayerModelService.Snapshot s) {
        // Explicit overrides in the DB always win (ops/QA can pin values).
        Integer overrideBoost = s.drawLookAheadBoost();
        Double overridePity = s.dryPityMultiplier();
        Double overrideBalancer = s.openingBalancerChance();

        int lookAhead = DrawBrain.LOOK_AHEAD_WINDOW
            + (overrideBoost == null ? 0 : overrideBoost);
        int dryThreshold = DrawBrain.DRY_DRAW_THRESHOLD;
        double pity = overridePity == null ? 1.0 : overridePity;
        double balancer = overrideBalancer == null
            ? DrawBrain.OPENING_BALANCER_CHANCE : overrideBalancer;
        int specialBoost = 0;

        // --- rule-based nudges ------------------------------------------
        boolean isNew = s.matchesPlayed() < 5;
        boolean isStrong = s.matchesPlayed() >= 20 && s.avgShowCount() > 0
            && s.avgShowCount() < 6;
        boolean isWeak = s.avgShowCount() > 15;
        boolean isFrustrated = s.dryDrawRate() > 0.35;
        boolean ignoresSpecial = s.specialUsageRate() > 0 && s.specialUsageRate() < 0.3;

        if (isNew && overrideBalancer == null) balancer = 0.90;
        if (isFrustrated && overridePity == null) pity = Math.max(pity, 1.5);
        if (isWeak && overridePity == null) pity = Math.max(pity, 1.3);
        if (isWeak && overrideBalancer == null) balancer = Math.max(balancer, 0.85);
        if (isStrong) {
            if (overrideBoost == null) lookAhead = 5;
            if (overridePity == null) pity = Math.min(pity, 0.7);
        }
        if (ignoresSpecial) specialBoost = 10;

        // Guard rails.
        lookAhead = Math.max(3, Math.min(12, lookAhead));
        pity = Math.max(0.0, Math.min(2.0, pity));
        balancer = Math.max(0.0, Math.min(1.0, balancer));

        return new AdaptiveDrawParams(lookAhead, dryThreshold, pity, balancer, specialBoost);
    }

    private record Cached(AdaptiveDrawParams params, long at) {}
}
