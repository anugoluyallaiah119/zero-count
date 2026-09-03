package com.zerocount.server.reward;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * R1.3 daily reward endpoints (Bearer-guarded):
 *
 *   GET  /api/rewards/daily        → {"canClaim":bool,"streak":N,
 *                                     "cycleDay":N,"todayReward":N,
 *                                     "lastClaimOn":"YYYY-MM-DD"|null}
 *   POST /api/rewards/daily/claim  → {"claimed":bool,"streak":N,"coins":N,
 *                                     "balance":N}  (idempotent per day)
 */
@RestController
@RequestMapping("/api/rewards/daily")
public class RewardController {

    private final DailyRewardService rewards;

    public RewardController(DailyRewardService rewards) {
        this.rewards = rewards;
    }

    @GetMapping
    public Map<String, Object> status(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        DailyRewardService.Status s = rewards.status(userId);
        return Map.of(
            "canClaim", s.canClaim(),
            "streak", s.streak(),
            "cycleDay", s.cycleDay(),
            "todayReward", s.todayReward(),
            "lastClaimOn", s.lastClaimOn() == null ? "" : s.lastClaimOn());
    }

    @PostMapping("/claim")
    public Map<String, Object> claim(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        DailyRewardService.ClaimResult r = rewards.claim(userId);
        return Map.of(
            "claimed", r.claimed(),
            "streak", r.streak(),
            "coins", r.coins(),
            "balance", r.balance());
    }
}
