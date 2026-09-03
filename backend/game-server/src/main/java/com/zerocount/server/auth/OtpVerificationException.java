package com.zerocount.server.auth;

/** Verification failed: bad session, wrong/expired code, or untrusted token. */
public class OtpVerificationException extends RuntimeException {
    public OtpVerificationException(String message) {
        super(message);
    }
}
