-- ---------------------------------------------------------------------------
-- V11: Achievements V2.3
-- ---------------------------------------------------------------------------

-- achievement_definitions: the catalogue of available badges.
CREATE TABLE IF NOT EXISTS achievement_definitions (
    id          TEXT PRIMARY KEY,
    title       TEXT NOT NULL,
    description TEXT NOT NULL,
    icon        TEXT NOT NULL,         -- emoji or asset id
    rarity      TEXT NOT NULL CHECK (rarity IN ('common','rare','epic','legendary')),
    reward_coins INT NOT NULL DEFAULT 0
);

-- user_achievements: earned badges per player (append-only, no revocation).
CREATE TABLE IF NOT EXISTS user_achievements (
    user_id     UUID      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id TEXT   NOT NULL REFERENCES achievement_definitions(id),
    earned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);

-- Seed the achievement catalogue.
INSERT INTO achievement_definitions (id, title, description, icon, rarity, reward_coins) VALUES
    ('first_win',         'First Blood',       'Win your very first match.',                          '🏆', 'common',    50),
    ('win_5',             'On a Roll',         'Win 5 matches.',                                      '🎯', 'common',    100),
    ('win_25',            'Veteran',           'Win 25 matches.',                                     '⚔️', 'rare',      250),
    ('win_100',           'Champion',          'Win 100 matches.',                                    '👑', 'epic',      500),
    ('streak_3',          'Hat-Trick',         'Win 3 matches in a row.',                             '🔥', 'common',    75),
    ('streak_5',          'On Fire',           'Win 5 matches in a row.',                             '🌟', 'rare',      200),
    ('streak_10',         'Unstoppable',       'Win 10 matches in a row.',                            '⚡', 'epic',      500),
    ('zero_score',        'Perfect Zero',      'End a match with a score of 0.',                      '0️⃣', 'rare',      150),
    ('zero_5',            'Zero Hero',         'Get a zero score in 5 matches.',                      '💎', 'epic',      300),
    ('special_used',      'Card Shark',        'Use the Special Card for the first time.',            '✨', 'common',    50),
    ('special_10',        'Special Specialist','Use the Special Card 10 times.',                      '🃏', 'rare',      200),
    ('friend_game',       'Social Butterfly',  'Play a match with a friend.',                         '🤝', 'common',    50),
    ('tournament_entry',  'Contender',         'Enter your first tournament.',                        '🏟️', 'common',    75),
    ('tournament_win',    'Trophy Hunter',     'Win a tournament.',                                   '🥇', 'legendary', 1000),
    ('coins_1000',        'Spender',           'Spend 1,000 coins in the store.',                     '💰', 'common',    0),
    ('collector_5',       'Collector',         'Own 5 cosmetic items.',                               '🎨', 'rare',      100)
ON CONFLICT (id) DO NOTHING;
