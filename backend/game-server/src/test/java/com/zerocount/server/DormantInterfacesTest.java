package com.zerocount.server;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zerocount.server.contest.Contest;
import com.zerocount.server.contest.ContestService;
import com.zerocount.server.notification.Notification;
import com.zerocount.server.notification.NotificationService;
import com.zerocount.server.wallet.Balance;
import com.zerocount.server.wallet.WalletService;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.stereotype.Service;

/**
 * E2.6 — dormant-interface guard.
 *
 * The Wallet/Contest/Notification contracts exist from V2.0, but per the
 * "foundation first, activate progressively" strategy they must NOT be
 * implemented until their phase. This test enforces that in CI:
 *
 *  1. The contracts are interfaces with no implementation classes.
 *  2. Nothing under the wallet/contest/notification packages carries a Spring
 *     bean stereotype (@Service/@Component/@RestController) — an accidental
 *     implementation would wire itself into the context and get called.
 *  3. The domain models validate their inputs (the parts that ARE complete).
 */
class DormantInterfacesTest {

    @Test
    void contractsAreInterfacesOnly() {
        assertThat(WalletService.class.isInterface()).isTrue();
        assertThat(ContestService.class.isInterface()).isTrue();
        assertThat(NotificationService.class.isInterface()).isTrue();
    }

    @Test
    void activationsAreImplementedAsSpringBeans() {
        // N1.1 / C1.1 / R1.6 activated these contracts — the beans exist now.
        assertThat(com.zerocount.server.wallet.JdbcWalletService.class
                .isAnnotationPresent(Service.class)).isTrue();
        assertThat(com.zerocount.server.contest.JdbcContestService.class
                .isAnnotationPresent(Service.class)).isTrue();
        assertThat(com.zerocount.server.notification.CappedNotificationService.class
                .isAnnotationPresent(Service.class)).isTrue();
    }

    @Test
    void domainModelsValidate() {
        assertThat(Balance.ZERO.coins()).isZero();
        assertThatThrownBy(() -> new Balance(-1, 0))
            .isInstanceOf(IllegalArgumentException.class);

        Instant now = Instant.now();
        Contest c = new Contest(java.util.UUID.randomUUID(), "Monthly Zero",
            "{}", now, now.plusSeconds(3600));
        assertThat(c.isLive(now.plusSeconds(10))).isTrue();
        assertThatThrownBy(() ->
            new Contest(java.util.UUID.randomUUID(), "Bad", "{}",
                now, now.minusSeconds(1)))
            .isInstanceOf(IllegalArgumentException.class);

        Notification n = new Notification(Notification.Kind.STREAK_AT_RISK, "Streak!", "Play today", null);
        assertThat(n.data()).isEmpty();
        assertThatThrownBy(() -> new Notification(null, "t", "b", null))
            .isInstanceOf(IllegalArgumentException.class);
    }

}
