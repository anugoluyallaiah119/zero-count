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
        return Map.of(
            "type", t.type(),
            "target", t.target(),
            "reward", t.reward(),
            "progress", t.progress(),
            "claimed", t.claimed(),
            "canClaim", t.canClaim());
    }
}
