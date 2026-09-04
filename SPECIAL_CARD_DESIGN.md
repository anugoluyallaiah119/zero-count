# Special Card Design — Zero Count V2

## Goal
Add a new card type (the "Special" card) to the core game loop that creates urgency and new decisions without breaking the locked V1 rules for normal cards.

## Rule
- The Special card is **not a joker** and does **not** join 3+ same-rank groups.
- It can be combined with **exactly 2 cards of the same rank** to form a **ZERO group of 3**.
  - Example: `7♥ + 7♦ + Special` counts as **0**.
  - Example: `10♠ + 10♣ + Special` counts as **0**.
- A Special card held unused has a face value of **10**.
- Two Special cards together do **not** form a zero group; each counts as 10.
- A Special card can be manually discarded like any other card.

## Decay (Urgency)
- Each Special card tracks how many of its current owner's turns it has been held while unusable.
- After **4 full owner turns** without a valid pair, it is automatically discarded face-up to the top of the discard pile at the end of the turn.
- The timer **pauses** whenever the Special has at least one valid pair target, so a usable Special never expires automatically.
- The age resets whenever a player draws the special (stock or discard), giving each owner a full 4-turn window from that point.
- This prevents hoarding and gives other players a chance to draw it.

## Distribution
| Players | Hand Size | Normal Cards | Special Cards in Deck |
|---------|-----------|--------------|------------------------|
| 2       | 7 or 13   | 52           | 1                      |
| 3       | 7 or 13   | 52           | 1                      |
| 4       | 7         | 60           | 1                      |
| 4       | 13        | 65           | 1                      |

Four-player modes use a small fractional second deck (15% for 7-card = 8 cards, 25% for 13-card = 13 cards) to keep duplicate availability healthy without shortening matches too much. The Special card is an extra card appended to the normal deck and then shuffled in.

## Engine Impact
Both the Dart offline engine and the Java server engine must behave identically.

1. `Card` gains an `isSpecial` flag.
2. `GameConfig` returns `specialCount() == 1` and `normalCardCount()` per the table above.
3. `DeckBuilder` builds the configured normal cards + one Special, then shuffles.
4. `ScoringEngine.optimize()` uses a Special only to complete a pair of **exactly 2** same-rank normal cards.
5. `GameSession` tracks special-card age, pauses the timer while usable, and auto-discards after 4 unusable owner turns.
6. New event: `SpecialDiscarded(seq, playerId, card)`.
7. `AiDecider` values specials only when an exact pair exists and discards dead specials otherwise.
8. Server JSON serialization includes `isSpecial`.
9. Flutter card widget renders specials distinctly.

## Implementation Status
- [x] Dart engine: `Card.isSpecial`, `GameConfig.normalCardCount`/`deckSize`/`specialCount`, `DeckBuilder` (fractional second deck + 1 special), `ScoringEngine` (exact-pair-only), `GameSession` 4-turn paused decay, `AiDecider`.
- [x] Java engine: `Card.isSpecial`, `GameConfig.normalCardCount`/`deckSize`/`specialCount`, `DeckBuilder` (fractional second deck + 1 special), `ScoringEngine` (exact-pair-only), `GameSession` 4-turn paused decay, `AiDecider`.
- [x] Server serialization: `isSpecial` on card JSON, `special_discarded` event.
- [x] Flutter UI: `ZcPlayingCard`, `MiniCard`, `LiveCard`, `ZcCardFan`, live/local play-area wiring.
- [x] Tests: Dart engine tests extended; Java engine tests extended.

## Test Plan
- Add dedicated special-card scoring tests (pair completion, unusable special = 10, no 3+ group joining).
- Verify timer behavior: usable Special pauses; unusable Special expires after 4 owner turns.
- Update simulation invariant tests to verify special decay and card conservation with the new deck sizes.
- Ensure existing 15 locked V1 rule tests still pass for normal cards.
- Run Java `run-tests.sh` and `flutter test` before finishing.
