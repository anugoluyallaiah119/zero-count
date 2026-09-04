-- ---------------------------------------------------------------------------
-- V7 (V2.2 Phase 3): rolled-up per-user gameplay profile.
--
-- The Phase 2 gameplay.* rows in analytics_events are the raw stream. This
-- table is a compact, denormalised projection the adaptive engine (Phase 4)
-- can read on every draw / opening deal without re-scanning the event log.
--
-- Updated append-style by PlayerModelService after every match_ended: we
-- overwrite the current-value columns and accumulate the *_total counters.
-- ---------------------------------------------------------------------------
CREATE TABLE player_gameplay_profile (
    user_id                    UUID PRIMARY KEY REFERENCES users(id),

    matches_played             INTEGER NOT NULL DEFAULT 0,
    rounds_played              INTEGER NOT NULL DEFAULT 0,
    total_show_count_sum       INTEGER NOT NULL DEFAULT 0,   -- for AVG at SHOW
    total_show_events          INTEGER NOT NULL DEFAULT 0,
    total_dry_draws            INTEGER NOT NULL DEFAULT 0,
    total_stock_draws          INTEGER NOT NULL DEFAULT 0,
    total_special_expired      INTEGER NOT NULL DEFAULT 0,
    total_special_seen         INTEGER NOT NULL DEFAULT 0,
    total_stalemates           INTEGER NOT NULL DEFAULT 0,

    -- Derived skill / engagement scalars, refreshed on every write.
    avg_show_count             REAL    NOT NULL DEFAULT 0,   -- proxy for accuracy
    dry_draw_rate              REAL    NOT NULL DEFAULT 0,   -- 0..1 frustration
    special_usage_rate         REAL    NOT NULL DEFAULT 0,   -- 0..1 mastery
    session_match_streak       INTEGER NOT NULL DEFAULT 0,   -- matches in a row today
    last_session_at            TIMESTAMPTZ,

    -- Adaptive weights (Phase 4 will consume these). Nulls = use defaults.
    draw_look_ahead_boost      SMALLINT,                     -- extra window past 9
    dry_pity_multiplier        REAL,                         -- scales soft pity
    opening_balancer_chance    REAL,                         -- overrides 0.72

    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX player_gameplay_profile_updated ON player_gameplay_profile (updated_at DESC);
