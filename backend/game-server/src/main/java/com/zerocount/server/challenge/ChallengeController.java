package com.zerocount.server.challenge;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * R1.4 daily challenge endpoints (Bearer-guarded):
 *
 *   GET  /api/challenges/today        → today's quest + my progress
 *   POST /api/challenges/claim        → pay the reward (idempotent)
 */
@RestController
@RequestMapping("/api/challenges")
public class ChallengeController {

    private final ChallengeService challenges;

    public ChallengeController(ChallengeService challenges) {
        this.challenges = challenges;
    }

    @GetMapping("/today")
    public Map<String, Object> today(HttpServletRequest req) {
        return json(challenges.today(AuthInterceptor.currentUserId(req)));
    }

    @PostMapping("/claim")
    public Map<String, Object> claim(HttpServletRequest req) {
        return json(challenges.claim(AuthInterceptor.currentUserId(req)));
    }

    private static Map<String, Object> json(ChallengeService.Today t) {
        var m = new java.util.LinkedHashMap<String, Object>();
        m.put("type",             t.type());
        m.put("title",            t.title());
        m.put("description",      t.description());
        m.put("cadence",          t.cadence());
        m.put("target",           t.target());
        m.put("reward",           t.rewardCoins()); // back-compat
        m.put("rewardCoins",      t.rewardCoins());
        m.put("rewardGems",       t.rewardGems());
        m.put("rewardCosmeticId", t.rewardCosmeticId());
        m.put("sponsorName",      t.sponsorName());
        m.put("progress",         t.progress());
        m.put("claimed",          t.claimed());
        m.put("canClaim",         t.canClaim());
        return m;
    }
}
