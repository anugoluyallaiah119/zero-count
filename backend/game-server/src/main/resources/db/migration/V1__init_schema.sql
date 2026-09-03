-- ============================================================================
-- Zero Count V2 — V1: full platform schema (roadmap §4).
--
-- Foundation-first strategy: the ENTIRE schema exists from V2.0, including
-- tables whose features activate in later phases. Dormant tables are marked
-- DORMANT with their activation phase. Nothing dormant gets service code
-- until its phase (E2.6 covers interfaces only).
--
-- Conventions:
--   * UUID PKs (gen_random_uuid) — safe for distributed inserts, no sequence
--     leakage of business volume.
--   * timestamptz everywhere; created/updated default now().
--   * Append-only ledgers (game_events, transactions) are enforced at the
--     database level by mutation-blocking triggers (standards §3.2).
--   * Money-like balances are bigint (smallest unit), never float.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid on PG < 13; harmless after

-- ---------------------------------------------------------------------------
-- ACTIVE from V2.0: identity
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       VARCHAR(15)  NOT NULL UNIQUE,          -- E.164, OTP-verified (E2.3)
    name        VARCHAR(50),
    avatar      VARCHAR(255),
    coins       BIGINT NOT NULL DEFAULT 0 CHECK (coins >= 0),  -- display cache; wallets is source of truth (V2.4)
    gems        BIGINT NOT NULL DEFAULT 0 CHECK (gems  >= 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- ACTIVE from V2.0: games, rounds, event log
-- ---------------------------------------------------------------------------
CREATE TABLE games (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_json JSONB NOT NULL,                        -- GameConfig snapshot: players, handSize, target
    started_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at    TIMESTAMPTZ,
    winner_id   UUID REFERENCES users(id)
);

CREATE TABLE game_players (
    game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    final_score INTEGER,
    placement   SMALLINT,                              -- 1 = winner
    PRIMARY KEY (game_id, user_id)
);
CREATE INDEX idx_game_players_user ON game_players (user_id);

CREATE TABLE rounds (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    seq         INTEGER NOT NULL,                      -- round number within the game, 1-based
    shower_id   UUID REFERENCES users(id),             -- who called SHOW
    counts_json JSONB NOT NULL,                        -- per-seat count breakdown for the scoreboard
    UNIQUE (game_id, seq)
);

-- Append-only event log (#29): every engine GameEvent, in order, per game.
CREATE TABLE game_events (
    game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    seq         BIGINT NOT NULL,                       -- matches GameEvent.seq()
    actor_id    UUID REFERENCES users(id),
    type        VARCHAR(32) NOT NULL,
    payload_json JSONB NOT NULL,
    ts          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (game_id, seq)
);

-- ---------------------------------------------------------------------------
-- ACTIVE from V2.0: player statistics
-- ---------------------------------------------------------------------------
CREATE TABLE statistics (
    user_id      UUID PRIMARY KEY REFERENCES users(id),
    matches      INTEGER NOT NULL DEFAULT 0,
    wins         INTEGER NOT NULL DEFAULT 0,
    zeros_made   INTEGER NOT NULL DEFAULT 0,           -- rounds finished at count 0
    best_count   INTEGER,                              -- lowest count ever shown; NULL = never showed
    streak_days  INTEGER NOT NULL DEFAULT 0,
    elo          INTEGER NOT NULL DEFAULT 1200
);

-- ---------------------------------------------------------------------------
-- DORMANT (activates V2.3 — Engagement): friends, achievements, challenges
-- ---------------------------------------------------------------------------
CREATE TABLE friendships (
    user_id     UUID NOT NULL REFERENCES users(id),
    friend_id   UUID NOT NULL REFERENCES users(id),
    status      VARCHAR(16) NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, friend_id),
    CHECK (user_id <> friend_id)
);
CREATE INDEX idx_friendships_friend ON friendships (friend_id);

CREATE TABLE achievements (
    user_id     UUID NOT NULL REFERENCES users(id),
    key         VARCHAR(64) NOT NULL,                  -- e.g. 'first_zero', 'streak_7'
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, key)
);

CREATE TABLE daily_challenges (
    id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date    DATE NOT NULL UNIQUE,
    type    VARCHAR(32) NOT NULL,
    target  INTEGER NOT NULL,
    reward  JSONB NOT NULL                             -- e.g. {"coins": 50}
);

-- ---------------------------------------------------------------------------
-- DORMANT (activates V2.4 — Monetization): wallet + append-only ledger
-- ---------------------------------------------------------------------------
CREATE TABLE wallets (
    user_id    UUID PRIMARY KEY REFERENCES users(id),
    coins      BIGINT NOT NULL DEFAULT 0 CHECK (coins >= 0),
    gems       BIGINT NOT NULL DEFAULT 0 CHECK (gems  >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only money ledger: every coin/gem movement is an immutable row.
CREATE TABLE transactions (
    id      BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    type    VARCHAR(32) NOT NULL,                      -- e.g. 'match_reward', 'purchase', 'daily_bonus'
    amount  BIGINT NOT NULL,                           -- signed; positive = credit
    ref     VARCHAR(128),                              -- idempotency key / external reference
    ts      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_transactions_user_ts ON transactions (user_id, ts);

-- ---------------------------------------------------------------------------
-- DORMANT (activates V2.5 — Contests)
-- ---------------------------------------------------------------------------
CREATE TABLE contests (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title      VARCHAR(120) NOT NULL,
    rules_json JSONB NOT NULL,
    starts_at  TIMESTAMPTZ NOT NULL,
    ends_at    TIMESTAMPTZ NOT NULL,
    sponsor_id UUID,
    CHECK (ends_at > starts_at)
);

CREATE TABLE contest_entries (
    contest_id  UUID NOT NULL REFERENCES contests(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    score       INTEGER NOT NULL DEFAULT 0,
    rank        INTEGER,
    reward_json JSONB,
    PRIMARY KEY (contest_id, user_id)
);
CREATE INDEX idx_contest_entries_user ON contest_entries (user_id);

-- ---------------------------------------------------------------------------
-- Append-only enforcement (standards §3.2): ledger rows must never change.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION prevent_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'append-only table % does not allow %', TG_TABLE_NAME, TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER game_events_no_mutation
    BEFORE UPDATE OR DELETE ON game_events
    FOR EACH ROW EXECUTE FUNCTION prevent_mutation();

CREATE TRIGGER transactions_no_mutation
    BEFORE UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION prevent_mutation();

-- updated_at maintenance for mutable balance rows.
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wallets_touch_updated_at
    BEFORE UPDATE ON wallets
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
