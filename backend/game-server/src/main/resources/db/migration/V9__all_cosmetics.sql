-- ---------------------------------------------------------------------------
-- V9 (N1.5): Extend shop catalog to all cosmetic categories.
--   avatar | table_theme | special_card | effect | sticker
-- Prices (coins): 1 coin ≈ 0.01 INR; ₹9=900c ₹19=1900c ₹29=2900c ₹49=4900c
--                 ₹79=7900c ₹99=9900c ₹149=14900c ₹199=19900c
-- ---------------------------------------------------------------------------

ALTER TABLE shop_items
    DROP CONSTRAINT shop_items_kind_check;

ALTER TABLE shop_items
    ADD CONSTRAINT shop_items_kind_check
    CHECK (kind IN (
        'card_back', 'table_theme', 'avatar',
        'special_card', 'effect', 'sticker', 'mascot'
    ));

-- Equipped columns on users (safe to run even if already added by V8).
ALTER TABLE users ADD COLUMN IF NOT EXISTS equipped_avatar      VARCHAR(40);
ALTER TABLE users ADD COLUMN IF NOT EXISTS equipped_theme       VARCHAR(40);
ALTER TABLE users ADD COLUMN IF NOT EXISTS equipped_special     VARCHAR(40);
ALTER TABLE users ADD COLUMN IF NOT EXISTS equipped_effect      VARCHAR(40);
ALTER TABLE users ADD COLUMN IF NOT EXISTS equipped_sticker_set VARCHAR(40);

-- ---- AVATARS (15 skins, from free → ₹199) --------------------------------
INSERT INTO shop_items (id, kind, name, price_coins) VALUES
    ('av_default',   'avatar', 'Default Ace',      0),
    ('av_cyber',     'avatar', 'Cyber Zero',     900),
    ('av_fox',       'avatar', 'Neon Kid',       900),
    ('av_robot',     'avatar', 'Shadow Bot',    1900),
    ('av_queen',     'avatar', 'Aurora Queen',  1900),
    ('av_panda',     'avatar', 'Chill Panda',   2900),
    ('av_ninja',     'avatar', 'Silent Ace',    2900),
    ('av_king',      'avatar', 'Retro King',    4900),
    ('av_wizard',    'avatar', 'Pixel Wizard',  4900),
    ('av_tiger',     'avatar', 'Tiger Blaze',   7900),
    ('av_owl',       'avatar', 'Cosmic Owl',    7900),
    ('av_alien',     'avatar', 'Quantum Ghost', 7900),
    ('av_knight',    'avatar', 'Samurai Zero',  9900),
    ('av_phoenix',   'avatar', 'Phoenix Rise', 14900),
    ('av_dragon',    'avatar', 'Ice Dragon',   19900)
ON CONFLICT DO NOTHING;

-- ---- TABLE THEMES (10 themes, from free → ₹199) --------------------------
INSERT INTO shop_items (id, kind, name, price_coins) VALUES
    ('th_brazil_carnival', 'table_theme', 'Brazil Carnival',    0),
    ('th_galaxy',          'table_theme', 'Cosmic Drift',     1900),
    ('th_sakura',          'table_theme', 'Sakura Calm',      1900),
    ('th_desert',          'table_theme', 'Brazil Beats',     2900),
    ('th_zen',             'table_theme', 'Zen Garden',       2900),
    ('th_neon',            'table_theme', 'Neon City',        4900),
    ('th_atlantis',        'table_theme', 'Desert Mirage',    4900),
    ('th_felt',            'table_theme', 'Forest Whisper',   7900),
    ('th_ocean',           'table_theme', 'Ocean Depths',     7900),
    ('th_flow',            'table_theme', 'Abstract Flow',    9900)
ON CONFLICT DO NOTHING;

-- ---- SPECIAL CARD SKINS (16 skins) ----------------------------------------
INSERT INTO shop_items (id, kind, name, price_coins) VALUES
    ('sp_classic',       'special_card', 'Cosmic Ace',      0),
    ('sp_inferno',       'special_card', 'Inferno King',  1900),
    ('sp_forest',        'special_card', 'Forest Queen',  1900),
    ('sp_thunder',       'special_card', 'Thunder Jack',  2900),
    ('sp_golden_ten',    'special_card', 'Golden 10',     4900),
    ('sp_frost_nine',    'special_card', 'Frost 9',       2900),
    ('sp_neon_eight',    'special_card', 'Neon 8',        2900),
    ('sp_blossom_seven', 'special_card', 'Blossom 7',     1900),
    ('sp_shadow_six',    'special_card', 'Shadow 6',      1900),
    ('sp_crystal_five',  'special_card', 'Crystal 5',     4900),
    ('sp_lava_four',     'special_card', 'Lava 4',        2900),
    ('sp_royal_three',   'special_card', 'Royal 3',       9900),
    ('sp_pulse_two',     'special_card', 'Pulse 2',       2900),
    ('sp_radiant_ace',   'special_card', 'Radiant Ace',  14900),
    ('sp_mystic_joker',  'special_card', 'Mystic Joker',  7900),
    ('sp_phoenix_zero',  'special_card', 'Phoenix Zero', 19900)
ON CONFLICT DO NOTHING;

-- ---- EFFECTS (8 effects) ---------------------------------------------------
INSERT INTO shop_items (id, kind, name, price_coins) VALUES
    ('ef_lightning',  'effect', 'Electric Spark',  0),
    ('ef_frost',      'effect', 'Ice Shard',     1900),
    ('ef_fireworks',  'effect', 'Fire Burst',    1900),
    ('ef_rainbow',    'effect', 'Neon Trail',    2900),
    ('ef_hearts',     'effect', 'Nature Flow',   2900),
    ('ef_golden',     'effect', 'Golden Glow',   7900),
    ('ef_confetti',   'effect', 'Confetti',      4900),
    ('ef_shadow',     'effect', 'Dark Matter',   4900)
ON CONFLICT DO NOTHING;

-- ---- STICKERS (12 stickers) ------------------------------------------------
INSERT INTO shop_items (id, kind, name, price_coins) VALUES
    ('st_gg',    'sticker', 'GG Champ',     0),
    ('st_nice',  'sticker', 'Well Played!', 0),
    ('st_wow',   'sticker', 'No Way!',      0),
    ('st_fire',  'sticker', "Let's Go!",    0),
    ('st_lol',   'sticker', 'Thanks!',      0),
    ('st_cry',   'sticker', 'Oops!',      900),
    ('st_zero',  'sticker', 'Boom!',       900),
    ('st_think', 'sticker', 'Unlucky!',   1900),
    ('st_love',  'sticker', 'Take it Easy',900),
    ('st_angry', 'sticker', 'Fire!',      1900),
    ('st_crown', 'sticker', 'Crown',      4900),
    ('st_luck',  'sticker', '100 Points', 1900)
ON CONFLICT DO NOTHING;

-- Give every existing user the free defaults.
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'av_default'       FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'th_brazil_carnival' FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'sp_classic'       FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'ef_lightning'     FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'st_gg'            FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'st_nice'          FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'st_wow'           FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'st_fire'          FROM users ON CONFLICT DO NOTHING;
INSERT INTO owned_items (user_id, item_id)
SELECT id, 'st_lol'           FROM users ON CONFLICT DO NOTHING;

-- Equip defaults where not already set.
UPDATE users SET
    equipped_avatar      = COALESCE(equipped_avatar, 'av_default'),
    equipped_theme       = COALESCE(equipped_theme, 'th_brazil_carnival'),
    equipped_special     = COALESCE(equipped_special, 'sp_classic'),
    equipped_effect      = COALESCE(equipped_effect, 'ef_lightning'),
    equipped_sticker_set = COALESCE(equipped_sticker_set, 'st_gg');
