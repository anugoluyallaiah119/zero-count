package com.zerocount.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Zero Count V2 game server — entry point.
 *
 * Server-authoritative (standards §1.1): every game mutation is validated and
 * applied by the engine on the server; clients only send intents (moves).
 */
@SpringBootApplication
public class ZeroCountServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ZeroCountServerApplication.class, args);
    }
}
