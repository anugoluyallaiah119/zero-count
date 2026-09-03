# ZERO COUNT V2 — Engineering Standards

**Applies to all code in this repository. A PR that violates these does not merge.**
This is a real multiplayer product, not a prototype — write code like other people
will maintain, attack, and depend on it.

---

## 1. Core Design Principles

1. **Server is the single source of truth.** Clients render and send intents.
   Every rule, score, and shuffle is decided server-side. The client NEVER
   decides game outcomes.
2. **Immutability by default.** Game state transitions produce new state objects;
   no in-place mutation of shared state. `Card`, `GameConfig`, `ScoreResult` are
   immutable. Mutable collections never escape a class unwrapped.
3. **Pure engine, zero dependencies.** `game-engine` module: no Spring, no I/O,
   no clocks, no randomness from the environment — all randomness is injected
   (`Random`/`SecureRandom` parameter). Same inputs + same seed = same game.
   This is what makes replays, dispute resolution, and 10k-match sims possible.
4. **Fail fast, fail loud.** Constructors and public methods validate arguments
   and throw `IllegalArgumentException`/`IllegalStateException` immediately.
   No silent null-tolerance, no swallowed exceptions.
5. **Explicit state machine.** Game flow only through `Phase` transitions in
   `GameSession`. No boolean flag soup (`isDrawing && !hasDrawn...` is forbidden).
6. **Small, single-purpose classes.** A class does one thing. A method does one
   thing. If a method needs a comment to explain a block, extract the block.
7. **No magic values.** All constants are named (`TURN_CAP`, `SHOW_THRESHOLD_BASE`).
   No unexplained numbers in logic.

## 2. Security Principles (non-negotiable)

1. **Validate every input at the trust boundary.** Every API body, every WebSocket
   message, every move: validate shape, range, and *authorization* ("is it THIS
   player's turn? does THIS player hold this card?"). Never trust the client.
2. **Server-side randomness only.** Shuffles use `SecureRandom` on the server.
   Clients never receive seeds. Hidden cards are never sent to other clients —
   the WS protocol omits card data other players must not see.
3. **Append-only money/critical data.** Wallets and transactions are ledgers:
   INSERT only, never UPDATE balances — balances are derived. Same for game events.
4. **Rate limiting on every mutating endpoint and WS action.**
5. **No secrets in code.** All secrets via environment/config service. No tokens,
   keys, or credentials in source, tests, or logs.
6. **Least data in responses.** API returns only what the caller needs. Opponent
   hands are card-count only until showdown.
7. **Parameterized queries only** (JPA/named params). Zero string-concatenated SQL.
8. **Audit trail.** Every state-changing action is logged with actor, timestamp,
   and payload — you cannot debug or dispute a multiplayer game without this.

## 3. Code Quality Bar

1. **Tests are part of "done."** A story is not complete without tests:
   unit tests for logic, invariant tests for engine, contract tests for APIs.
2. **Engine acceptance gate (permanent):** the 15 locked V1 rule tests +
   10,000 simulated matches with invariants must pass on every CI run.
   A red gate blocks all merges.
3. **Deterministic tests.** All tests use seeded randomness. No `Thread.sleep`
   in tests, no wall-clock dependence.
4. **No dead code, no commented-out code, no TODO without a story ID.**
   `// TODO(E1.4): ...` is fine; bare `// fix later` is not.
5. **Names say what things are.** `bestDiscardIdx` not `calc`. Public API names
   match the blueprint vocabulary (DRAW, DISCARD, SHOW, stock, discard pile).
6. **Error codes over string matching.** API errors use the frozen code list
   (blueprint §5). New codes require a contract change + doc bump.
7. **Logging:** structured, no card contents of hidden hands in logs, no PII
   beyond user id. Never log auth tokens or OTP codes.

## 4. Java/Backend Conventions

- Java 17+, Spring Boot 3.x. `final` fields, constructor injection (no field `@Autowired`).
- Records for value objects; sealed types for command/event hierarchies (`Move`).
- Service boundaries: cross-module calls through interfaces only (blueprint §2).
- DB: Flyway migrations only — never edit an applied migration; add a new one.
- All monetary/ledger integers in smallest unit (paise/coins as long), never float.

## 5. Flutter Conventions

- Riverpod for state; widgets are dumb, logic lives in providers/notifiers.
- Animations are pure functions of state + tick; no hidden imperative timers
  outside the animation layer.
- The local Dart engine is used ONLY for offline single-player; it must pass
  the same 15 rule tests as the Java engine.

## 6. Definition of Done (per story)

- [ ] Code follows §1–§5
- [ ] Tests written and green (incl. engine gate if engine touched)
- [ ] No new compiler/lint warnings
- [ ] Public API changes reflected in the blueprint (doc version bumped)
- [ ] Tracker: story → Completed, next story → In Progress
