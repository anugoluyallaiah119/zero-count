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
 * V2.4 — In-App Purchase server-side verification.
 *
 * The client purchases a coin/gem pack via Google Play or App Store. The
 * platform SDK delivers a signed receipt/token. The client sends it here;
 * the server verifies with the platform API and credits the wallet.
 *
 *   POST /api/wallet/iap-claim
 *     {"platform":"google"|"apple", "productId":"cb_iap_1000_coins",
 *      "purchaseToken":"…", "nonce":"client-uuid"}
 *
 * Platform verification is STUBBED — replace the TODO blocks with the real
 * Google Play Developer API or App Store Server API calls once you have
 * Google Play Console + Apple developer accounts. The rest of the flow is
 * fully wired.
 *
 * Idempotent on nonce (ref = "iap:{user}:{nonce}") — receipt replays are
 * silently ignored so the client can safely retry on network errors.
 */
@RestController
@RequestMapping("/api/wallet")
public class IapController {

    private final JdbcTemplate db;
    private final WalletService wallet;

    /** Product catalog: productId → coin grant. Mirrors the Flutter IapCatalog. */
    private static final java.util.Map<String, Long> COIN_GRANTS = Map.of(
        "zc_coins_1000",   1_000L,
        "zc_coins_5000",   5_000L,
        "zc_coins_10000", 10_000L,
        "zc_coins_25000", 25_000L
    );

    private static final java.util.Map<String, Long> GEM_GRANTS = Map.of(
        "zc_gems_60",      60L,
        "zc_gems_250",    250L,
        "zc_gems_520",    520L,
        "zc_gems_1100",  1_100L
    );

    public IapController(JdbcTemplate db, WalletService wallet) {
        this.db = db;
        this.wallet = wallet;
    }

    public record IapClaimBody(String platform, String productId,
                               String purchaseToken, String nonce) {}

    @PostMapping("/iap-claim")
    public Map<String, Object> claim(@RequestBody IapClaimBody body,
                                     HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        validate(body);
        String ref = "iap:" + userId + ":" + body.nonce();

        // Idempotency guard — replay returns current balance without double-pay.
        Integer dup = db.queryForObject(
            "SELECT COUNT(*) FROM transactions WHERE user_id = ? AND ref = ?",
            Integer.class, userId, ref);
        if (dup != null && dup > 0) {
            return Map.of("granted", false, "reason", "already_claimed",
                "balance", wallet.balance(userId).coins());
        }

        // ---------- Platform verification ---------------------------------
        // TODO (Google Play): call
        //   https://androidpublisher.googleapis.com/androidpublisher/v3/applications
        //   /{packageName}/purchases/products/{productId}/tokens/{purchaseToken}
        //   with your service-account OAuth2 bearer token.
        //   Check purchaseState == 0 (purchased) and acknowledge if not already.
        //
        // TODO (App Store): call
        //   https://api.storekit.itunes.apple.com/inApps/v1/transactions/{transactionId}
        //   with your signed JWT from your Apple private key.
        //   Check status == 0 (valid).
        //
        // For now, trust the client. Production MUST verify before granting coins.
        boolean verified = true; // STUB — replace with real verification above.
        if (!verified) {
            return Map.of("granted", false, "reason", "receipt_invalid",
                "balance", wallet.balance(userId).coins());
        }
        // ------------------------------------------------------------------

        Long coins = COIN_GRANTS.get(body.productId());
        Long gems = GEM_GRANTS.get(body.productId());

        if (coins != null) {
            var bal = wallet.creditCoins(userId, coins, WalletTxType.PURCHASE, ref);
            return Map.of("granted", true, "type", "coins",
                "amount", coins, "balance", bal.coins());
        }
        if (gems != null) {
            // Gem ledger reuses coins column; gems stored in gems column.
            db.update(
                "UPDATE wallets SET gems = gems + ? WHERE user_id = ?", gems, userId);
            db.update("""
                INSERT INTO transactions (user_id, type, amount, ref)
                VALUES (?, 'purchase_gems', ?, ?)
                """, userId, gems, ref);
            long newGems = db.queryForObject(
                "SELECT gems FROM wallets WHERE user_id = ?", Long.class, userId);
            return Map.of("granted", true, "type", "gems",
                "amount", gems, "gems", newGems);
        }

        throw new IllegalArgumentException("unknown product: " + body.productId());
    }

    private static void validate(IapClaimBody b) {
        if (b.platform() == null || (!b.platform().equals("google") && !b.platform().equals("apple")))
            throw new IllegalArgumentException("platform must be google or apple");
        if (b.productId() == null || b.productId().isBlank())
            throw new IllegalArgumentException("productId required");
        if (b.purchaseToken() == null || b.purchaseToken().isBlank())
            throw new IllegalArgumentException("purchaseToken required");
        if (b.nonce() == null || b.nonce().isBlank() || b.nonce().length() > 64)
            throw new IllegalArgumentException("nonce required (≤64 chars)");
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(Map.of("error", e.getMessage()));
    }
}
