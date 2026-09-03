package com.zerocount.server.auth;

import jakarta.validation.constraints.NotBlank;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Auth REST contract (E2.3):
 *
 *   POST /api/auth/otp/request   {"phone":"+919876543210"}        → {"session":"..."}
 *   POST /api/auth/otp/verify    {"session":"...","code":"123456"} → token bundle
 *   POST /api/auth/refresh       {"refreshToken":"..."}            → rotated token bundle
 *
 * Errors are uniform 4xx JSON: {"error":"<reason>"} — no stack traces, no
 * hints about which phones exist (standards §3.4).
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    public record OtpRequest(@NotBlank String phone) {}
    public record OtpVerify(@NotBlank String session, String code) {}
    public record RefreshRequest(@NotBlank String refreshToken) {}

    @PostMapping("/otp/request")
    public Map<String, String> requestOtp(@RequestBody OtpRequest req) {
        return Map.of("session", auth.requestOtp(req.phone()));
    }

    @PostMapping("/otp/verify")
    public Map<String, Object> verifyOtp(@RequestBody OtpVerify req) {
        return toBody(auth.verifyOtp(req.session(), req.code()));
    }

    @PostMapping("/refresh")
    public Map<String, Object> refresh(@RequestBody RefreshRequest req) {
        return toBody(auth.refresh(req.refreshToken()));
    }

    private static Map<String, Object> toBody(AuthService.TokenBundle b) {
        return Map.of(
            "accessToken", b.accessToken(),
            "tokenType", "Bearer",
            "expiresIn", b.accessExpiresInSec(),
            "refreshToken", b.refreshToken(),
            "userId", b.userId().toString(),
            "newUser", b.newUser()
        );
    }

    @ExceptionHandler({OtpVerificationException.class, JwtService.InvalidTokenException.class})
    public ResponseEntity<Map<String, String>> authFailure(RuntimeException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, String>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
}
