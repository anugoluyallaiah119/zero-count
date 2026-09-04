-- V4: Engagement phase (V2.3) — daily reward claims, device tokens,
-- notification prefs, shop catalog + ownership.
-- Append-only and CHECK-guarded like the V1 ledgers.

-- R1.3: one row per user per day; streak is derived from consecutive dates.
CREATE TABLE daily_reward_claims (
    user_id      UUID NOT NULL REFERENCES users(id),
    claimed_on   DATE NOT NULL,
    streak       INTEGER NOT NULL CHECK (streak >= 1),
    reward_coins INTEGER NOT NULL CHECK (reward_coins > 0),
    PRIMARY KEY (user_id, claimed_on)
);

-- R1.6: FCM device tokens, one row per device.
CREATE TABLE device_tokens (
    user_id    UUID NOT NULL REFERENCES users(id),
    fcm_token  VARCHAR(255) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, fcm_token)
);

-- R1.6: per-user opt-out per notification kind.
CREATE TABLE notification_mutes (
    user_id UUID NOT NULL REFERENCES users(id),
    kind    VARCHAR(32) NOT NULL,
    PRIMARY KEY (user_id, kind)
);

-- R1.6: respectful-cap bookkeeping (max 1 unsolicited push/day).
CREATE TABLE notification_log (
    id      BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    kind    VARCHAR(32) NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_notification_log_user_day
    ON notification_log (user_id, sent_at);

-- R1.4: per-user progress/claim state for the (global) daily challenge.
CREATE TABLE daily_challenge_progress (
    user_id      UUID NOT NULL REFERENCES users(id),
    challenge_id UUID NOT NULL REFERENCES daily_challenges(id) ON DELETE CASCADE,
    progress     INTEGER NOT NULL DEFAULT 0 CHECK (progress >= 0),
    claimed      BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (user_id, challenge_id)
);

-- N1.3: cosmetics catalog (seed rows below) and ownership.
CREATE TABLE shop_items (
    id         VARCHAR(40) PRIMARY KEY,          -- e.g. 'back.aurora'
    kind       VARCHAR(16) NOT NULL
               CHECK (kind IN ('card_back', 'table_theme', 'mascot')),
    name       VARCHAR(60) NOT NULL,
    price_coins INTEGER NOT NULL CHECK (price_coins >= 0)
);
CREATE TABLE owned_items (
    user_id UUID NOT NULL REFERENCES users(id),
    item_id VARCHAR(40) NOT NULL REFERENCES shop_items(id),
    PRIMARY KEY (user_id, item_id)
);

INSERT INTO shop_items (id, kind, name, price_coins) VALUES
    ('back.classic_blue', 'card_back', 'Classic Blue', 100),
    ('back.aurora',       'card_back', 'Aurora', 300),
    ('back.crimson',      'card_back', 'Crimson', 300),
    ('theme.midnight',    'table_theme', 'Midnight Felt', 500),
    ('theme.emerald',     'table_theme', 'Emerald Felt', 500),
    ('mascot.zippy',      'mascot', 'Zippy the Zero', 800);
