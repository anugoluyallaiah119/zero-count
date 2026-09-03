package com.zerocount.server.auth;

/**
 * Phone-number verification — the OTP abstraction (E2.3).
 *
 * Two implementations:
 *  - dev:      deterministic fixed code, in-memory sessions (local + CI only)
 *  - firebase: production; the Flutter client completes Firebase phone OTP and
 *              sends the resulting Firebase ID token, which we verify against
 *              Google's published certs
 *
 * Keeping this behind an interface means auth logic and tests never depend on
 * an SMS gateway.
 */
public interface PhoneAuthProvider {

    /**
     * Start an OTP verification for {@code phone} (E.164).
     * @return an opaque session handle the client passes back with the code.
     */
    String startVerification(String phone);

    /**
     * Complete a verification.
     * @param session handle from {@link #startVerification} (Firebase mode: the ID token)
     * @param code    the OTP the user typed (Firebase mode: ignored, may be null)
     * @return the verified phone number in E.164
     * @throws OtpVerificationException if the session/code is invalid or expired
     */
    String confirmVerification(String session, String code);
}
