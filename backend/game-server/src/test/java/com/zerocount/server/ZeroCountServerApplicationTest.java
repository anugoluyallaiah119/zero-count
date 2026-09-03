package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;

/** E2.1 smoke test: context boots against real Postgres, ping and health UP. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ZeroCountServerApplicationTest extends EmbeddedPostgresSupport {

    @LocalServerPort
    int port;

    @Autowired
    TestRestTemplate rest;

    @Test
    void contextLoads() {
        // context boot alone is the assertion
    }

    @Test
    void pingRespondsOk() {
        String body = rest.getForObject("http://localhost:" + port + "/api/ping", String.class);
        assertThat(body).contains("\"status\":\"ok\"").contains("zerocount-game-server");
    }

    @Test
    void actuatorHealthIsUp() {
        String body = rest.getForObject("http://localhost:" + port + "/actuator/health", String.class);
        assertThat(body).contains("UP");
    }
}
