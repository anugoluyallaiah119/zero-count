package com.zerocount.server.shop;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.transaction.annotation.Transactional;
import com.zerocount.server.player.AuthInterceptor;
import com.zerocount.server.wallet.WalletService;
import com.zerocount.server.wallet.WalletTxType;

/**
 * N1.3 — cosmetics shop: card backs, table themes, mascots. All purchases
 * are virtual coins through the wallet (SHOP_SPEND), idempotent per item
 * (re-buying an owned item is a no-op returning the balance).
 *
 *   GET  /api/shop          → catalog with owned flags
 *   POST /api/shop/buy      {"itemId":"back.aurora"}
 *   GET  /api/shop/mine     → owned item ids
 */
@RestController
@RequestMapping("/api/shop")
public class ShopController {

    private final JdbcTemplate db;
    private final WalletService wallet;

    public ShopController(JdbcTemplate db, WalletService wallet) {
        this.db = db;
        this.wallet = wallet;
    }

    public record BuyBody(String itemId) {}

    @GetMapping
    public List<Map<String, Object>> catalog(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        return db.query("""
            SELECT s.id, s.kind, s.name, s.price_coins,
                   EXISTS (SELECT 1 FROM owned_items o
                           WHERE o.user_id = ? AND o.item_id = s.id) AS owned
            FROM shop_items s ORDER BY s.kind, s.price_coins
            """, (rs, n) -> Map.of(
                "id", rs.getString("id"),
                "kind", rs.getString("kind"),
                "name", rs.getString("name"),
                "priceCoins", rs.getInt("price_coins"),
                "owned", rs.getBoolean("owned")),
            userId);
    }

    @PostMapping("/buy")
    @Transactional
    public Map<String, Object> buy(@RequestBody BuyBody body, HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        var rows = db.queryForList(
            "SELECT price_coins FROM shop_items WHERE id = ?", body.itemId());
        if (rows.isEmpty()) throw new IllegalArgumentException("unknown item");
        int price = ((Number) rows.get(0).get("price_coins")).intValue();
        Integer owned = db.queryForObject(
            "SELECT COUNT(*) FROM owned_items WHERE user_id = ? AND item_id = ?",
            Integer.class, userId, body.itemId());
        if (owned == null || owned == 0) {
            var bal = wallet.debitCoins(userId, price, WalletTxType.SHOP_SPEND,
                "shop:" + userId + ":" + body.itemId());
            db.update("INSERT INTO owned_items (user_id, item_id) VALUES (?,?)",
                userId, body.itemId());
            return Map.of("owned", true, "balance", bal.coins());
        }
        return Map.of("owned", true, "balance", wallet.balance(userId).coins());
    }

    @GetMapping("/mine")
    public List<String> mine(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        return db.queryForList(
            "SELECT item_id FROM owned_items WHERE user_id = ?", String.class, userId);
    }

    public record EquipBody(String itemId) {}

    /** Equip a card back the player owns. Only card_back kind is supported for now. */
    @PostMapping("/equip")
    @Transactional
    public Map<String, Object> equip(@RequestBody EquipBody body, HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        var rows = db.queryForList(
            "SELECT kind FROM shop_items WHERE id = ?", body.itemId());
        if (rows.isEmpty()) throw new IllegalArgumentException("unknown item");
        Integer owned = db.queryForObject(
            "SELECT COUNT(*) FROM owned_items WHERE user_id = ? AND item_id = ?",
            Integer.class, userId, body.itemId());
        if (owned == null || owned == 0)
            throw new IllegalArgumentException("item not owned");
        String kind = (String) rows.get(0).get("kind");
        String col = switch (kind) {
            case "card_back"    -> "equipped_card_back";
            case "avatar"       -> "equipped_avatar";
            case "table_theme"  -> "equipped_theme";
            case "special_card" -> "equipped_special";
            case "effect"       -> "equipped_effect";
            case "sticker"      -> "equipped_sticker_set";
            default -> null;
        };
        if (col != null) {
            db.update("UPDATE users SET " + col + " = ? WHERE id = ?",
                body.itemId(), userId);
        }
        return Map.of("equipped", true, "itemId", body.itemId(), "kind", kind);
    }

    @ExceptionHandler(WalletService.InsufficientFundsException.class)
    public ResponseEntity<Map<String, Object>> insufficient(
            WalletService.InsufficientFundsException e) {
        return ResponseEntity.status(HttpStatus.PAYMENT_REQUIRED)
            .body(Map.of("error", "not_enough_coins"));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
}
