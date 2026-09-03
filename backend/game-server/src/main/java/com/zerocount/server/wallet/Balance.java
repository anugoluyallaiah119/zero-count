package com.zerocount.server.wallet;

/**
 * Virtual-currency balance snapshot. Money-like values are long (smallest
 * unit), never float (standards §3.2). Read-only view of the `wallets` table.
 */
public record Balance(long coins, long gems) {

    public Balance {
        if (coins < 0 || gems < 0)
            throw new IllegalArgumentException("balance cannot be negative");
    }

    public static final Balance ZERO = new Balance(0, 0);
}
