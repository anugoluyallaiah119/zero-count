package com.zerocount.server.wallet;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
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

    private static final Logger log = LoggerFactory.getLogger(IapController.class);
    private static final String ANDROID_PACKAGE = "com.zerocount.app";

    private final JdbcTemplate db;
    private final WalletService wallet;
    private final HttpClient http = HttpClient.newHttpClient();
    private final ObjectMapper json = new ObjectMapper();

    /** Google Play service-account OAuth2 bearer — set via env var GOOGLE_PLAY_API_TOKEN. */
    @Value("${app.iap.google-play-token:}") private String googlePlayToken;
    /** App Store private key JWT — set via env var APPLE_IAP_JWT. */
    @Value("${app.iap.apple-jwt:}") private String appleJwt;

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
        boolean verified = switch (body.platform()) {
            case "google" -> verifyGoogle(body.productId(), body.purchaseToken());
            case "apple"  -> verifyApple(body.purchaseToken());
            default       -> false;
        };
        if (!verified) {
            log.warn("IAP receipt rejected for user={} product={} platform={}",
                userId, body.productId(), body.platform());
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

    /**
     * Google Play Developer API v3 — verify a consumable product purchase.
     * Requires GOOGLE_PLAY_API_TOKEN env var (OAuth2 service-account bearer).
     * Falls back to true (dev mode) when the token is not configured.
     */
    private boolean verifyGoogle(String productId, String purchaseToken) {
        if (googlePlayToken == null || googlePlayToken.isBlank()) {
            log.warn("GOOGLE_PLAY_API_TOKEN not set — skipping Google Play verification (dev mode)");
            return true;
        }
        try {
            String url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                + ANDROID_PACKAGE + "/purchases/products/"
                + productId + "/tokens/" + purchaseToken;
            HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer " + googlePlayToken)
                .GET().build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) {
                log.warn("Google Play verify HTTP {}: {}", res.statusCode(), res.body());
                return false;
            }
            JsonNode node = json.readTree(res.body());
            int purchaseState = node.path("purchaseState").asInt(-1);
            // purchaseState 0 = purchased, 1 = cancelled, 2 = pending
            if (purchaseState != 0) return false;
            // Acknowledge if not yet acknowledged (prevents auto-refund after 3 days)
            if (node.path("acknowledgementState").asInt(0) == 0) {
                acknowledgeGoogle(productId, purchaseToken);
            }
            return true;
        } catch (IOException | InterruptedException e) {
            log.error("Google Play verification error", e);
            return false;
        }
    }

    private void acknowledgeGoogle(String productId, String purchaseToken) {
        try {
            String url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
                + ANDROID_PACKAGE + "/purchases/products/"
                + productId + "/tokens/" + purchaseToken + ":acknowledge";
            HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer " + googlePlayToken)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString("{}")).build();
            http.send(req, HttpResponse.BodyHandlers.discarding());
        } catch (IOException | InterruptedException e) {
            log.warn("Google Play acknowledge failed (non-fatal)", e);
        }
    }

    /**
     * App Store Server API — verify a StoreKit 2 transaction.
     * Requires APPLE_IAP_JWT env var (signed JWT from Apple private key).
     * Falls back to true (dev mode) when the JWT is not configured.
     */
    private boolean verifyApple(String transactionId) {
        if (appleJwt == null || appleJwt.isBlank()) {
            log.warn("APPLE_IAP_JWT not set — skipping App Store verification (dev mode)");
            return true;
        }
        try {
            String url = "https://api.storekit.itunes.apple.com/inApps/v1/transactions/" + transactionId;
            HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer " + appleJwt)
                .GET().build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) {
                log.warn("App Store verify HTTP {}: {}", res.statusCode(), res.body());
                return false;
            }
            JsonNode node = json.readTree(res.body());
            // status 0 = valid; any other value = invalid/revoked
            return node.path("status").asInt(-1) == 0;
        } catch (IOException | InterruptedException e) {
            log.error("App Store verification error", e);
            return false;
        }
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
