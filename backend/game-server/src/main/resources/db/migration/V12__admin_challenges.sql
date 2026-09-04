-- ---------------------------------------------------------------------------
-- V12: Admin-pushed challenges (daily / weekly / monthly + sponsored).
-- ---------------------------------------------------------------------------

-- Extend daily_challenges with scheduling, rich rewards, push flag.
-- The existing date column becomes active_from; we add active_until for
-- weekly/monthly windows. Old rows keep working (active_until = date + 1d).

ALTER TABLE daily_challenges
    ADD COLUMN IF NOT EXISTS title       TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS cadence     VARCHAR(8) NOT NULL DEFAULT 'daily'
        CHECK (cadence IN ('daily','weekly','monthly')),
    ADD COLUMN IF NOT EXISTS active_from  DATE,
    ADD COLUMN IF NOT EXISTS active_until DATE,
    ADD COLUMN IF NOT EXISTS reward_coins  INTEGER NOT NULL DEFAULT 0
        CHECK (reward_coins >= 0),
    ADD COLUMN IF NOT EXISTS reward_gems   INTEGER NOT NULL DEFAULT 0
        CHECK (reward_gems  >= 0),
    ADD COLUMN IF NOT EXISTS reward_cosmetic_id VARCHAR(40)
        REFERENCES shop_items(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS sponsor_id   UUID
        REFERENCES sponsors(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS notify_on_start BOOLEAN NOT NULL DEFAULT true,
    ADD COLUMN IF NOT EXISTS created_by  TEXT,
    ADD COLUMN IF NOT EXISTS push_sent   BOOLEAN NOT NULL DEFAULT false;

-- Back-fill active_from / active_until from the existing date column.
UPDATE daily_challenges
SET active_from  = date,
    active_until = date + INTERVAL '1 day',
    reward_coins = COALESCE((reward->>'coins')::int, 0)
WHERE active_from IS NULL;

-- Index for the scheduler: find challenges whose window just opened.
CREATE INDEX IF NOT EXISTS idx_challenges_active
    ON daily_challenges (active_from, active_until, push_sent);
