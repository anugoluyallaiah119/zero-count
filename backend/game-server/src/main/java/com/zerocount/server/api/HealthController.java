package com.zerocount.server.api;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Lightweight ping/version endpoint for load-balancer checks and deploy
 * verification. Deep health (DB, Redis) is served by /actuator/health as
 * those subsystems come online in later stories (E2.2+).
 */
@RestController
public class HealthController {

    private final String appVersion;

    public HealthController(@Value("${app.version:unknown}") String appVersion) {
        this.appVersion = appVersion;
    }

    @GetMapping("/api/ping")
    public Map<String, String> ping() {
        return Map.of(
            "status", "ok",
            "service", "zerocount-game-server",
            "version", appVersion
        );
    }
}
