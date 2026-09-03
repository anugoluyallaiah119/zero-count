package com.zerocount.server.contest;

import java.util.List;
import java.util.UUID;

/**
 * ⚠️ DORMANT — activates in V2.5 (Contests, story C1.1). INTERFACE ONLY.
 *
 * Do NOT implement this in V2.0–V2.4. The contract exists so contest
 * surfaces (Flutter screens, reward distribution) have a stable API to
 * build against when the phase opens.
 *
 * Implementation rules when activated:
 *  - Entry scores update server-side only, derived from completed matches.
 *  - Rewards are distributed via WalletService with type CONTEST_REWARD,
 *    one idempotent ledger row per (contest, user).
 *  - Rank ties share the better rank (dense ranking decided at activation).
 */
public interface ContestService {

    /** Currently live contests, soonest-ending first. */
    List<Contest> listActive();

    /** Register a user into a contest (idempotent). */
    void enter(UUID contestId, UUID userId);

    public record Standing(UUID userId, int score, int rank) {}

    /** Leaderboard for a contest, rank ascending. */
    List<Standing> standings(UUID contestId, int limit);
}
