-- ---------------------------------------------------------------------------
-- V8 (N1.4): Card back cosmetics — replace placeholder SKUs with the
-- 9 real designs. Prices in coins map to approximate rupee values:
--   ₹9  = 900 coins  |  ₹19 = 1,900  |  ₹29 = 2,900  |  ₹49 = 4,900
--   ₹79 = 7,900      |  ₹99 = 9,900
-- Default 'cb_classic' is free (owned by every user on sign-up via trigger).
-- ---------------------------------------------------------------------------

-- Allow free default items (price_coins = 0)
ALTER TABLE shop_items
    DROP CONSTRAINT IF EXISTS shop_items_price_coins_check;

ALTER TABLE shop_items
    ADD CONSTRAINT shop_items_price_coins_check
    CHECK (price_coins >= 0);

-- Drop old placeholder rows that are no longer valid.
DELETE FROM shop_items WHERE kind = 'card_back';

-- Insert the 9 card back SKUs.
INSERT INTO shop_items (id, kind, name, price_coins) VALUES
    ('cb_classic',  'card_back', 'Zero Classic',    0),
    ('cb_midnight', 'card_back', 'Midnight Pulse',  900),
    ('cb_amethyst', 'card_back', 'Amethyst Veil',   1900),
    ('cb_ember',    'card_back', 'Ember Core',      2900),
    ('cb_arctic',   'card_back', 'Arctic Frost',    2900),
    ('cb_galaxy',   'card_back', 'Cosmic Drift',    4900),
    ('cb_sakura',   'card_back', 'Sakura Storm',    4900),
    ('cb_inferno',  'card_back', 'Inferno Ace',     7900),
    ('cb_obsidian', 'card_back', 'Obsidian Crown',  9900);

-- Add equipped_card_back to users so the game knows which back to render.
ALTER TABLE users ADD COLUMN IF NOT EXISTS equipped_card_back VARCHAR(40)
    REFERENCES shop_items(id) DEFAULT 'cb_classic';

-- Give every existing user the free classic card back.
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'cb_classic' FROM users
ON CONFLICT DO NOTHING;

-- Equip the classic for every user who hasn't equipped anything yet.
UPDATE users SET equipped_card_back = 'cb_classic'
WHERE equipped_card_back IS NULL;
