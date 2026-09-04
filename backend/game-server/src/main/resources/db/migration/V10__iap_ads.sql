-- ---------------------------------------------------------------------------
-- V10 (V2.4): IAP + rewarded-ads foundation.
-- ---------------------------------------------------------------------------

-- Ad-reward policy updated: 50 coins, 2/day (was 25c/5d). No schema change
-- needed — the cap is enforced in application code.

-- IAP: add gems column index for fast balance reads in IapController.
CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets (user_id);

-- Expose remaining ad quota as a view for monitoring / analytics queries.
CREATE OR REPLACE VIEW daily_ad_rewards AS
SELECT user_id,
       COUNT(*) AS ads_today,
       SUM(amount) AS coins_today
FROM transactions
WHERE type = 'ad_reward'
  AND ts > now() - interval '1 day'
GROUP BY user_id;
