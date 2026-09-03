package com.zerocount.server.contest;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.zerocount.server.match.MatchHook;
import com.zerocount.server.wallet.WalletService;
import com.zerocount.server.wallet.WalletTxType;

/**
 * C1.1 + C1.3 — ContestService activation: monthly challenges, entry,
 * standings (dense ranking), and end-of-contest reward distribution.
 *
 * A monthly contest ("ZERO LEAGUE · 2026-08") is created lazily on first
 * access and runs 1st→last day of the month UTC. Scoring accrues from
 * completed matches via {@link MatchHook}: win = +3, participation = +1.
 *
 * When a contest ends, the next read distributes rewards idempotently —
 * top 3: 500 / 300 / 150 coins — one CONTEST_REWARD ledger row per
 * (contest, user) with ref "contest:{contestId}:{userId}".
 */
@Service
public class JdbcContestService implements ContestService, MatchHook {

    static final int SCORE_WIN = 3;
    static final int SCORE_PLAY = 1;
    static final long[] PODIUM_COINS = {500, 300, 150};

    private final JdbcTemplate db;
    private final WalletService wallet;

    public JdbcContestService(JdbcTemplate db, WalletService wallet) {
        this.db = db;
        this.wallet = wallet;
    }

    // ---- ContestService ---------------------------------------------------

    @Override
    public List<Contest> listActive() {
        UUID monthly = ensureMonthlyContest();
        distributeEndedRewards();
        return db.query(
            "SELECT * FROM contests WHERE ends_at > now() ORDER BY ends_at",
            (rs, n) -> toContest(rs));
    }

    @Override
    public void enter(UUID contestId, UUID userId) {
        db.update("INSERT INTO contest_entries (contest_id, user_id) "
                + "VALUES (?,?) ON CONFLICT DO NOTHING", contestId, userId);
    }

    @Override
    public List<Standing> standings(UUID contestId, int limit) {
        List<Object[]> rows = db.query(
            "SELECT user_id, score FROM contest_entries "
                + "WHERE contest_id = ? ORDER BY score DESC, user_id LIMIT ?",
            (rs, n) -> new Object[]{rs.getObject("user_id", UUID.class),
                rs.getInt("score")},
            contestId, limit);
        // Dense ranking: ties share the better rank.
        List<Standing> out = new ArrayList<>();
        int rank = 0, lastScore = Integer.MIN_VALUE, i = 0;
        for (Object[] r : rows) {
            i++;
            int score = (Integer) r[1];
            if (score != lastScore) { rank = i; lastScore = score; }
            out.add(new Standing((UUID) r[0], score, rank));
        }
        return out;
    }

    // ---- MatchHook --------------------------------------------------------

    @Override
    @Transactional
    public void onMatchEnded(List<UUID> seats, int winnerIdx, List<Integer> totals) {
        UUID monthly = ensureMonthlyContest();
        for (int i = 0; i < seats.size(); i++) {
            int delta = SCORE_PLAY + (i == winnerIdx ? SCORE_WIN - SCORE_PLAY : 0);
            int d = i == winnerIdx ? SCORE_WIN : SCORE_PLAY;
            // Only entered players score (entering is free + explicit).
            db.update("UPDATE contest_entries SET score = score + ? "
                    + "WHERE contest_id = ? AND user_id = ?", d, monthly, seats.get(i));
        }
    }

    // ---- internals --------------------------------------------------------

    /** This month's contest, created on first access (idempotent). */
    public UUID ensureMonthlyContest() {
        YearMonth ym = YearMonth.now(ZoneOffset.UTC);
        Instant start = ym.atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC);
        Instant end = ym.plusMonths(1).atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC);
        String title = "ZERO LEAGUE · " + ym;
        db.update("""
            INSERT INTO contests (title, rules_json, starts_at, ends_at)
            SELECT ?, ?::jsonb, ?, ?
            WHERE NOT EXISTS (SELECT 1 FROM contests WHERE title = ?)
            """, title, "{\"scoring\":\"win=3, play=1\",\"podium\":[500,300,150]}",
            Timestamp.from(start), Timestamp.from(end), title);
        return db.queryForObject("SELECT id FROM contests WHERE title = ?",
            UUID.class, title);
    }

    /** C1.3: pay podium rewards for contests that ended undistributed. */
    @Transactional
    public void distributeEndedRewards() {
        List<UUID> ended = db.queryForList(
            "SELECT id FROM contests WHERE ends_at <= now() "
                + "AND rules_json->>'distributed' IS NULL", UUID.class);
        for (UUID contestId : ended) {
            List<Standing> podium = standings(contestId, 3);
            for (Standing s : podium) {
                if (s.rank() > PODIUM_COINS.length) break;
                long coins = PODIUM_COINS[s.rank() - 1];
                wallet.creditCoins(s.userId(), coins, WalletTxType.CONTEST_REWARD,
                    "contest:" + contestId + ":" + s.userId());
                db.update("UPDATE contest_entries SET rank = ?, "
                        + "reward_json = ?::jsonb "
                        + "WHERE contest_id = ? AND user_id = ?",
                    s.rank(), "{\"coins\": " + coins + "}", contestId, s.userId());
            }
            db.update("UPDATE contests SET rules_json = rules_json || "
                    + "'{\"distributed\": true}'::jsonb WHERE id = ?", contestId);
        }
    }

    private static Contest toContest(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new Contest(
            rs.getObject("id", UUID.class),
            rs.getString("title"),
            rs.getString("rules_json"),
            rs.getTimestamp("starts_at").toInstant(),
            rs.getTimestamp("ends_at").toInstant());
    }
}
