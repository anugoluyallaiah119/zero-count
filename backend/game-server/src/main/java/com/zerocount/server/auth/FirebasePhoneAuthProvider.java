package com.zerocount.server.auth;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.PublicKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Production OTP provider (app.auth.provider=firebase).
 *
 * Flow: the Flutter app completes Firebase phone-auth client-side and sends us
 * the Firebase ID token. We verify it the documented way: RS256 signature
 * against Google's public certs (securetoken issuer), plus issuer/audience/
 * expiry checks, then read the verified phone from the token claims.
 *
 * Ref: https://firebase.google.com/docs/auth/admin/verify-id-tokens
 *
 * startVerification() is unsupported here — the client SDK owns the SMS round
 * trip; the server only verifies the resulting token.
 */
@Component
@ConditionalOnProperty(name = "app.auth.provider", havingValue = "firebase")
public class FirebasePhoneAuthProvider implements PhoneAuthProvider {

    private static final Logger log = LoggerFactory.getLogger(FirebasePhoneAuthProvider.class);
    private static final String CERTS_URL =
        "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@google.com";
    private static final String ISSUER_PREFIX = "https://securetoken.google.com/";
    private static final Duration CERT_CACHE_TTL = Duration.ofHours(6);

    private final String projectId;
    private final HttpClient http = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(10)).build();
    private final ObjectMapper json = new ObjectMapper();

    private volatile Map<String, RSAPublicKey> certs = Map.of();
    private volatile Instant certsFetchedAt = Instant.EPOCH;

    public FirebasePhoneAuthProvider(@Value("${app.firebase.project-id:}") String projectId) {
        if (projectId == null || projectId.isBlank()) {
            // Fail fast (standards §1.4): a firebase provider without a project
            // id would accept nothing anyway — refuse to start.
            throw new IllegalStateException("app.firebase.project-id is required when app.auth.provider=firebase");
        }
        this.projectId = projectId;
    }

    @Override
    public String startVerification(String phone) {
        throw new UnsupportedOperationException(
            "Firebase mode: the client SDK performs OTP; call confirmVerification with the ID token");
    }

    @Override
    public String confirmVerification(String session, String code) {
        String idToken = session;
        try {
            String kid = readKid(idToken);
            RSAPublicKey key = certs().get(kid);
            if (key == null) {
                refreshCerts();
                key = certs().get(kid);
            }
            if (key == null) throw new OtpVerificationException("unknown signing key");

            Claims claims = Jwts.parser()
                .verifyWith(key)
                .requireIssuer(ISSUER_PREFIX + projectId)
                .requireAudience(projectId)
                .build()
                .parseSignedClaims(idToken)
                .getPayload();

            Object phone = claims.get("phone_number");
            if (phone == null || phone.toString().isBlank()) {
                throw new OtpVerificationException("token has no verified phone_number");
            }
            return phone.toString();
        } catch (OtpVerificationException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Firebase ID token verification failed: {}", e.getMessage());
            throw new OtpVerificationException("invalid Firebase ID token");
        }
    }

    /** Read the kid header without trusting the token body yet. */
    private String readKid(String jwt) {
        try {
            String headerJson = new String(Base64.getUrlDecoder().decode(jwt.split("\\.")[0]));
            Map<String, Object> header = json.readValue(headerJson, new TypeReference<>() {});
            Object kid = header.get("kid");
            if (kid == null) throw new OtpVerificationException("token missing kid header");
            return kid.toString();
        } catch (OtpVerificationException e) {
            throw e;
        } catch (Exception e) {
            throw new OtpVerificationException("malformed ID token");
        }
    }

    private Map<String, RSAPublicKey> certs() {
        if (Instant.now().isAfter(certsFetchedAt.plus(CERT_CACHE_TTL))) refreshCerts();
        return certs;
    }

    private synchronized void refreshCerts() {
        if (!Instant.now().isAfter(certsFetchedAt.plus(Duration.ofMinutes(1)))) return; // stampede guard
        try {
            HttpRequest req = HttpRequest.newBuilder(URI.create(CERTS_URL)).timeout(Duration.ofSeconds(10)).build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) throw new IllegalStateException("cert fetch HTTP " + res.statusCode());
            Map<String, String> jwks = json.readValue(res.body(), new TypeReference<>() {});
            Map<String, RSAPublicKey> fresh = new ConcurrentHashMap<>();
            for (Map.Entry<String, String> e : jwks.entrySet()) {
                // Endpoint returns x509 PEM certs; convert to RSA public key.
                String pem = e.getValue()
                    .replace("-----BEGIN CERTIFICATE-----", "")
                    .replace("-----END CERTIFICATE-----", "")
                    .replaceAll("\\s", "");
                byte[] der = Base64.getDecoder().decode(pem);
                var cert = java.security.cert.CertificateFactory.getInstance("X.509")
                    .generateCertificate(new java.io.ByteArrayInputStream(der));
                PublicKey pk = cert.getPublicKey();
                fresh.put(e.getKey(), (RSAPublicKey) pk);
            }
            certs = fresh;
            certsFetchedAt = Instant.now();
        } catch (Exception e) {
            // Keep serving the stale cache rather than hard-fail verification.
            log.error("Failed to refresh Firebase signing certs: {}", e.getMessage());
        }
    }
}
