package com.zerocount.server.wallet;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * Wallet read API (N1.1). Mutations go through domain services (rewards,
 * shop, contests) — never raw client debits.
 *
 *   GET /api/wallet → {"coins":N,"gems":N,"ledger":[…last 20…]}
 */
@RestController
@RequestMapping("/api/wallet")
public class WalletController {

    private final WalletService wallet;
    private final JdbcTemplate db;

    public WalletController(WalletService wallet, JdbcTemplate db) {
        this.wallet = wallet;
        this.db = db;
    }

    @GetMapping
    public Map<String, Object> balance(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        Balance b = wallet.balance(userId);
        List<Map<String, Object>> ledger = db.queryForList(
            "SELECT type, amount, ref, ts FROM transactions "
                + "WHERE user_id = ? ORDER BY id DESC LIMIT 20", userId);
        return Map.of("coins", b.coins(), "gems", b.gems(), "ledger", ledger);
    }
}
