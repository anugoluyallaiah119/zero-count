package com.zerocount.server.wallet;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * N1.2 — rewarded-ad grant endpoint (server half; the family-safe ad SDK
 * wiring is client-side). The client watches an ad, the ad network confirms
 * via its SDK, and the client claims here with a one-time nonce:
 *
 *   POST /api/wallet/ad-reward {"nonce":"uuid-from-client"}
 *
 * Policy: +25 coins per completed ad, max 5 grants per user per UTC day.
 * Idempotent on the nonce (ref = "ad:{user}:{nonce}") — replays don't pay.
 */
@RestController
@RequestMapping("/api/wallet")
public class AdRewardController {

    static final int REWARD_COINS = 25;
    static final int DAILY_CAP = 5;

    private final JdbcTemplate db;
    private final WalletService wallet;

    public AdRewardController(JdbcTemplate db, WalletService wallet) {
        this.db = db;
        this.wallet = wallet;
    }

    public record NonceBody(String nonce) {}

    @PostMapping("/ad-reward")
    public Map<String, Object> claim(@RequestBody NonceBody body,
                                     HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        if (body.nonce() == null || body.nonce().isBlank()
                || body.nonce().length() > 64) {
            throw new IllegalArgumentException("nonce required");
        }
        String ref = "ad:" + userId + ":" + body.nonce();
        Integer dup = db.queryForObject(
            "SELECT COUNT(*) FROM transactions WHERE user_id = ? AND ref = ?",
            Integer.class, userId, ref);
        if (dup != null && dup > 0) {
            return Map.of("granted", false, "balance",
                wallet.balance(userId).coins());
        }
        Integer today = db.queryForObject(
            "SELECT COUNT(*) FROM transactions WHERE user_id = ? "
                + "AND type = 'ad_reward' AND ts > now() - interval '1 day'",
            Integer.class, userId);
        if (today != null && today >= DAILY_CAP) {
            return Map.of("granted", false, "dailyCapReached", true,
                "balance", wallet.balance(userId).coins());
        }
        var bal = wallet.creditCoins(userId, REWARD_COINS, WalletTxType.AD_REWARD, ref);
        return Map.of("granted", true, "coins", REWARD_COINS, "balance", bal.coins());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(Map.of("error", e.getMessage()));
    }
}
