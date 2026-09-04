package com.zerocount.server;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Zero Count V2 game server — entry point.
 */
@SpringBootApplication
@EnableScheduling
public class ZeroCountServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ZeroCountServerApplication.class, args);
    }
}
