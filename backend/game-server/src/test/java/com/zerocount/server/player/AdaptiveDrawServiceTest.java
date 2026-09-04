package com.zerocount.server.player;

import static org.assertj.core.api.Assertions.assertThat;

import com.zerocount.engine.session.AdaptiveDrawParams;
import com.zerocount.engine.session.DrawBrain;
import org.junit.jupiter.api.Test;

/**
 * V2.2 Phase 4 — pure-function tests for the adaptive rule table. No
 * database, no Spring — just verifies the rule logic on hand-crafted
 * {@link PlayerModelService.Snapshot} inputs.
 */
class AdaptiveDrawServiceTest {

    static PlayerModelService.Snapshot snap(int matches, double avgShow,
                                            double dryRate, double specialUsage) {
        return new PlayerModelService.Snapshot(
            matches, 0, 0, avgShow, dryRate, specialUsage, null, null, null);
    }

    @Test
    void defaultsForBaselinePlayer() {
        AdaptiveDrawParams p = AdaptiveDrawService.compute(snap(10, 8, 0.15, 0.6));
        assertThat(p.lookAheadWindow()).isEqualTo(DrawBrain.LOOK_AHEAD_WINDOW);
        assertThat(p.openingBalancerChance()).isEqualTo(DrawBrain.OPENING_BALANCER_CHANCE);
        assertThat(p.dryPityMultiplier()).isEqualTo(1.0);
        assertThat(p.specialUtilityBoost()).isZero();
    }

    @Test
    void newPlayerGetsAggressiveOpeningBalancer() {
        AdaptiveDrawParams p = AdaptiveDrawService.compute(snap(2, 0, 0, 0));
        assertThat(p.openingBalancerChance()).isEqualTo(0.90);
    }

    @Test
    void frustratedPlayerGetsHeavierSoftPity() {
        AdaptiveDrawParams p = AdaptiveDrawService.compute(snap(30, 8, 0.5, 0.6));
        assertThat(p.dryPityMultiplier()).isGreaterThanOrEqualTo(1.5);
    }

    @Test
    void weakPlayerGetsExtraHelp() {
        AdaptiveDrawParams p = AdaptiveDrawService.compute(snap(30, 18, 0.2, 0.5));
        assertThat(p.dryPityMultiplier()).isGreaterThanOrEqualTo(1.3);
        assertThat(p.openingBalancerChance()).isGreaterThanOrEqualTo(0.85);
    }

    @Test
    void strongPlayerGetsLessHandholding() {
        AdaptiveDrawParams p = AdaptiveDrawService.compute(snap(50, 4, 0.1, 0.9));
        assertThat(p.lookAheadWindow()).isEqualTo(5);
        assertThat(p.dryPityMultiplier()).isLessThanOrEqualTo(0.7);
    }

    @Test
    void playersIgnoringSpecialGetHigherUtilityBoost() {
        AdaptiveDrawParams p = AdaptiveDrawService.compute(snap(30, 10, 0.1, 0.1));
        assertThat(p.specialUtilityBoost()).isEqualTo(10);
    }

    @Test
    void dbOverridesAreRespected() {
        PlayerModelService.Snapshot s = new PlayerModelService.Snapshot(
            50, 0, 0, 4, 0.1, 0.9, 3, 1.7, 0.5);
        AdaptiveDrawParams p = AdaptiveDrawService.compute(s);
        // Even though the player looks "strong", explicit overrides win.
        assertThat(p.lookAheadWindow()).isEqualTo(DrawBrain.LOOK_AHEAD_WINDOW + 3);
        assertThat(p.dryPityMultiplier()).isEqualTo(1.7);
        assertThat(p.openingBalancerChance()).isEqualTo(0.5);
    }
}
