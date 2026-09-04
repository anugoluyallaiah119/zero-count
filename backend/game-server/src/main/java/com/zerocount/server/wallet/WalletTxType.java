package com.zerocount.server.wallet;

/** Why a wallet movement happened — maps to `transactions.type`. */
public enum WalletTxType {
    MATCH_REWARD,
    DAILY_BONUS,
    STREAK_BONUS,
    PURCHASE,          // V2.4 Play Billing (server-verified)
    SHOP_SPEND,        // V2.4 cosmetics
    CONTEST_REWARD,    // V2.5
    AD_REWARD,         // V2.4 rewarded ads (family-safe networks only)
    ACHIEVEMENT_REWARD,// V2.3 achievement badge coins
    ADMIN_ADJUST       // support tooling; audited
}
