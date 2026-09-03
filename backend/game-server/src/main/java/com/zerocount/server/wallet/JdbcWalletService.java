package com.zerocount.server.wallet;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * N1.1 — WalletService activation. Virtual currency only.
 *
 * Every mutation appends ONE row to the append-only `transactions` ledger
 * and updates `wallets` in the same database transaction. `ref` is the
 * idempotency key: a retry with an existing ref returns the current balance
 * without applying twice. The ledger's no-mutation trigger (V1 schema) makes
 * tampering impossible below the application layer.
 */
@Service
public class JdbcWalletService implements WalletService {

    private final JdbcTemplate db;

    public JdbcWalletService(JdbcTemplate db) {
        this.db = db;
    }

    @Override
    @Transactional
    public Balance balance(UUID userId) {
        ensureWallet(userId);
        return db.queryForObject(
                "SELECT coins, gems FROM wallets WHERE user_id = ?",
                (rs, n) -> toBalance(rs), userId);
    }

    @Override
    @Transactional
    public Balance creditCoins(UUID userId, long amount, WalletTxType type, String ref) {
        if (amount <= 0) throw new IllegalArgumentException("credit must be positive");
        ensureWallet(userId);
        if (alreadyApplied(userId, ref)) return balance(userId);
        db.update("INSERT INTO transactions (user_id, type, amount, ref) VALUES (?,?,?,?)",
                userId, type.name().toLowerCase(), amount, ref);
        db.update("UPDATE wallets SET coins = coins + ? WHERE user_id = ?", amount, userId);
        syncUserCoinsCache(userId);
        return balance(userId);
    }

    @Override
    @Transactional
    public Balance debitCoins(UUID userId, long amount, WalletTxType type, String ref) {
        if (amount <= 0) throw new IllegalArgumentException("debit must be positive");
        ensureWallet(userId);
        if (alreadyApplied(userId, ref)) return balance(userId);
        int updated = db.update(
                "UPDATE wallets SET coins = coins - ? WHERE user_id = ? AND coins >= ?",
                amount, userId, amount);
        if (updated == 0) {
            throw new InsufficientFundsException(
                    "debit of " + amount + " exceeds balance for " + userId);
        }
        db.update("INSERT INTO transactions (user_id, type, amount, ref) VALUES (?,?,?,?)",
                userId, type.name().toLowerCase(), -amount, ref);
        syncUserCoinsCache(userId);
        return balance(userId);
    }

    private void ensureWallet(UUID userId) {
        db.update("INSERT INTO wallets (user_id) VALUES (?) ON CONFLICT (user_id) DO NOTHING",
                userId);
    }

    private boolean alreadyApplied(UUID userId, String ref) {
        if (ref == null || ref.isBlank()) return false;
        Integer n = db.queryForObject(
                "SELECT COUNT(*) FROM transactions WHERE user_id = ? AND ref = ?",
                Integer.class, userId, ref);
        return n != null && n > 0;
    }

    /** Keep the denormalized users.coins display cache in step. */
    private void syncUserCoinsCache(UUID userId) {
        db.update("UPDATE users SET coins = (SELECT coins FROM wallets WHERE user_id = ?) "
                + "WHERE id = ?", userId, userId);
    }

    private static Balance toBalance(ResultSet rs) throws SQLException {
        return new Balance(rs.getLong("coins"), rs.getLong("gems"));
    }
}
