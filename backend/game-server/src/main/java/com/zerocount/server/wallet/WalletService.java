package com.zerocount.server.wallet;

import java.util.UUID;

/**
 * ⚠️ DORMANT — activates in V2.4 (Monetization, story N1.1). INTERFACE ONLY.
 *
 * Do NOT implement this in V2.0–V2.3 (roadmap "foundation first, activate
 * progressively"): no beans, no endpoints, no logic. The contract exists so
 * match rewards (N1.1), the shop (N1.3) and contests (C1.x) can be built
 * against a stable API later without reworking earlier code.
 *
 * Implementation rules when activated:
 *  - Every mutation appends ONE row to the append-only `transactions` ledger
 *    and updates `wallets` in the same transaction.
 *  - `ref` is the idempotency key: retrying with the same ref must not
 *    double-apply (check ledger first).
 *  - Virtual currency only — no real-money withdrawal, ever.
 */
public interface WalletService {

    /** Current balance for a user (creates a zero wallet on first access). */
    Balance balance(UUID userId);

    /** Credit coins. Returns the new balance. Idempotent on `ref`. */
    Balance creditCoins(UUID userId, long amount, WalletTxType type, String ref);

    /**
     * Debit coins. Idempotent on `ref`.
     * @throws InsufficientFundsException if the balance would go negative
     */
    Balance debitCoins(UUID userId, long amount, WalletTxType type, String ref);

    /** Thrown when a debit exceeds the available balance. */
    class InsufficientFundsException extends RuntimeException {
        public InsufficientFundsException(String message) { super(message); }
    }
}
