package com.zerocount.server.achievement;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.zerocount.server.player.AuthInterceptor;

/**
 * GET /api/achievements        — full catalogue with earned flag per user
 * GET /api/achievements/summary — {earned, total} for profile badge display
 */
@RestController
@RequestMapping("/api/achievements")
public class AchievementController {

    private final AchievementService svc;

    public AchievementController(AchievementService svc) {
        this.svc = svc;
    }

    @GetMapping
    public List<AchievementService.AchievementDto> list(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        return svc.listForUser(userId);
    }

    @GetMapping("/summary")
    public Map<String, Object> summary(HttpServletRequest req) {
        UUID userId = AuthInterceptor.currentUserId(req);
        List<AchievementService.AchievementDto> all = svc.listForUser(userId);
        long earned = all.stream().filter(AchievementService.AchievementDto::earned).count();
        return Map.of("earned", earned, "total", all.size());
    }
}
