package com.zerocount.engine.session;

/**
 * V2.2 Phase 4 — per-user tuning knobs for {@link DrawBrain}.
 *
 * Every field mirrors a DrawBrain constant; the Phase 4 adaptive layer
 * produces one instance per player based on their Phase 3 profile. Passing
 * {@link #DEFAULTS} reproduces the baseline V2.2 §32–39 behaviour.
 */
public record AdaptiveDrawParams(
    int lookAheadWindow,
    int dryDrawThreshold,
    double dryPityMultiplier,
    double openingBalancerChance,
    int specialUtilityBoost
) {
    public static final AdaptiveDrawParams DEFAULTS = new AdaptiveDrawParams(
        DrawBrain.LOOK_AHEAD_WINDOW,
        DrawBrain.DRY_DRAW_THRESHOLD,
        1.0,
        DrawBrain.OPENING_BALANCER_CHANCE,
        0
    );

    public AdaptiveDrawParams {
        if (lookAheadWindow < 1) throw new IllegalArgumentException("lookAheadWindow >= 1");
        if (dryDrawThreshold < 1) throw new IllegalArgumentException("dryDrawThreshold >= 1");
        if (dryPityMultiplier < 0) throw new IllegalArgumentException("dryPityMultiplier >= 0");
        if (openingBalancerChance < 0 || openingBalancerChance > 1)
            throw new IllegalArgumentException("openingBalancerChance in [0,1]");
    }
}
