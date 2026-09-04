# ZERO COUNT --- SPECIAL CARD & CORE GAME BRAIN

## Detailed Game Logic Specification

**Document:** `special_file.md`\
**Purpose:** Single reference for the Special Card system and the other
gameplay/algorithm changes implemented around it.

------------------------------------------------------------------------

## 1. Document Status

This document describes the current Zero Count gameplay brain based on
the latest `index.html` implementation and the game rules established
during testing.

There are three layers:

1.  **V1 rules** --- the basic Zero Count game.
2.  **V2/V2.2 improvements** --- card availability, pacing, opening
    opportunities, draw balancing and hand usability.
3.  **Special Card system** --- an additional strategic layer built on
    top of the normal game.

Where a discussion idea differs from the current implementation, this
document says so explicitly.

------------------------------------------------------------------------

## 2. Core Zero Count Concept

Zero Count is a low-score card game.

The objective is to make the player's remaining score as close to zero
as possible.

Core turn loop:

1.  Start with the normal hand size.
2.  See the visible top discard.
3.  Choose the draw deck or visible discard.
4.  Pick exactly one card.
5.  Temporarily hold one extra card.
6.  Choose one card to discard.
7.  Return to the normal hand size.
8.  Recalculate the optimized score.
9.  Optionally SHOW.
10. Continue to the next player.

The original game supports 2--4 players and 7-card or 13-card modes.

### 7-card mode

`7 → pick 1 → 8 → discard 1 → 7`

### 13-card mode

`13 → pick 1 → 14 → discard 1 → 13`

The player may discard the card they just picked.

------------------------------------------------------------------------

## 3. Card Values

  Rank           Value
  ------- ------------
  A                  1
  2--10     Face value
  J                 10
  Q                 10
  K                 10

J, Q and K remain different ranks even though they share value 10.

Therefore:

`10 + J + Q = 30`

and:

`J + Q + K = 30`

They do not form a zero group.

------------------------------------------------------------------------

## 4. Normal Zero Group

A normal zero group consists of **three or more cards with exactly the
same rank**.

Examples:

`2 2 2 → ZERO`

`5 5 5 → ZERO`

`8 8 8 8 → ZERO`

`J J J → ZERO`

`Q Q Q → ZERO`

`K K K → ZERO`

Four or more matching cards are also valid.

Matching is based on rank, not value.

Therefore:

`10 10 J` is not a group.

`J Q K` is not a group.

------------------------------------------------------------------------

## 5. No Standard Rummy Sequence Rule

The game does not use standard Rummy sequence scoring.

For example:

`7 8 9 = 24`

not zero.

Likewise:

`7 8 10 = 25`

The primary strategic mechanic is matching ranks and reducing score.

------------------------------------------------------------------------

# SPECIAL CARD SYSTEM

## 6. Why the Special Card Exists

Testing exposed a major gameplay problem: a player could wait many turns
for one exact duplicate card.

For example, a player could have:

`10 10`

and remain stuck waiting for another 10 to make:

`10 10 10 → ZERO`

The Special Card creates another route:

`10 10 + SPECIAL → ZERO`

This means the player is not completely dependent on drawing the exact
third card.

The Special Card is therefore a **pair-completion power**, not a general
wildcard.

------------------------------------------------------------------------

## 7. Basic Special Card Rule

The Special Card can complete a pair of the same rank.

Examples:

`10 + 10 + SPECIAL → ZERO`

`7 + 7 + SPECIAL → ZERO`

`5 + 5 + SPECIAL → ZERO`

The Special Card is consumed after successful use.

The two physical matching cards remain associated with the zero group.

------------------------------------------------------------------------

## 8. The Special Card Is Not a Joker

The Special Card is not:

-   a universal wildcard,
-   a sequence creator,
-   a free zero for any single card,
-   a card that changes rank,
-   a permanent protected card,
-   an automatic win.

Its specific purpose is:

> **Turn one valid same-rank pair into a zero group.**

This restriction is important for game balance.

------------------------------------------------------------------------

## 9. Valid Special Target

The current implementation searches for ranks that appear **exactly
twice** among normal cards.

Example:

`K K 7 7 4 6 SPECIAL`

Valid targets:

-   K K
-   7 7

The Special Card does not need to be used immediately if the player
wants to wait.

If a rank already has three matching cards:

`K K K`

that is already a normal zero group, so it is not treated as a Special
Card target.

------------------------------------------------------------------------

## 10. Multiple Valid Pairs

Suppose the player has:

`10 10 7 7 4 6 SPECIAL`

There are two possible targets:

### Option 1

`10 + 10 + SPECIAL`

Score reduction:

`20`

### Option 2

`7 + 7 + SPECIAL`

Score reduction:

`14`

The game therefore recommends the 10 pair.

The current target list is sorted by card value, highest first.

The first option is marked:

`BEST VALUE`

The player still makes the final choice.

------------------------------------------------------------------------

## 11. Highest-Value Reduction Principle

The primary Special Card decision rule is:

> **Use the Special Card where it produces the largest immediate score
> reduction.**

Priority:

1.  Find valid pairs.
2.  Calculate each pair's value.
3.  Rank pairs from highest to lowest.
4.  Recommend the largest reduction.
5.  Let the player choose.

Example:

`K K + SPECIAL = -20`

`9 9 + SPECIAL = -18`

Therefore K/K is recommended.

------------------------------------------------------------------------

## 12. No Valid Pair

This is a critical rule.

Example:

`7 9 10 K 4 6 SPECIAL`

There is no pair.

The Special Card cannot be activated.

It remains in the player's hand.

It does not automatically attach itself to 7, 9, 10 or K.

The player now has a new strategic objective:

> Find a card that creates a valid pair before the Special Card expires.

------------------------------------------------------------------------

## 13. Special Card Creates a Second Objective

Normal game question:

> "What card should I collect?"

With Special Card:

> "What card should I collect that can activate my Special Card?"

Example:

`7 9 10 SPECIAL`

The player may start pursuing another 7, 9 or 10 depending on the
situation.

This creates additional decision-making without changing the core rules.

------------------------------------------------------------------------

## 14. Special Card Timer

An unusable Special Card should not remain in the player's hand
indefinitely.

The current implementation gives an unusable Special Card a lifetime of:

**4 owner turns**

The timer is based on turns taken by the owner while the Special Card
remains unusable.

If the Special Card becomes usable, the timer stops progressing.

------------------------------------------------------------------------

## 15. Timer Example

Player receives:

`SPECIAL`

Hand:

`7 9 10 K 4 6 SPECIAL`

No pair.

Timer:

`4`

After the next owner turn without a valid pair:

`3`

Then:

`2`

Then:

`1`

If the player still has no usable pair when the lifetime is reached, the
current implementation expires the Special Card.

It is moved to the discard pile.

This prevents permanent dead weight.

------------------------------------------------------------------------

## 16. Why the Timer Matters

Without the timer, a player can hold the Special Card indefinitely and
wait for the perfect card.

That creates passive gameplay:

> "I'll wait."

With the timer:

> "I need to make a decision before this opportunity disappears."

This produces urgency and faster decision-making.

------------------------------------------------------------------------

## 17. Special Card Waiting Strategy

When the Special Card is unusable, the player may:

-   chase a useful duplicate,
-   take a visible discard,
-   change the cards they are building around,
-   decide to give up the Special Card,
-   continue reducing other high-value cards.

This makes the Special Card a strategic pressure mechanic rather than a
passive bonus.

------------------------------------------------------------------------

## 18. Special Card Arrival Animation

When the human player draws a Special Card, the current implementation
provides a dedicated short presentation.

It includes:

-   Special Card visual,
-   temporary overlay,
-   `SPECIAL CARD` title,
-   explanation: `Complete one matching pair into ZERO`
-   pop animation,
-   short sound effect.

The purpose is immediate recognition.

The animation should be short enough that it does not interrupt the game
flow.

------------------------------------------------------------------------

## 19. Special Card Visual

The current Special Card has:

-   dark purple premium background,
-   gold border,
-   central special symbol,
-   SPECIAL label,
-   small countdown badge,
-   subtle animated glow,
-   urgent pulse when one owner turn remains.

The visual hierarchy is:

**important, premium, but not distracting.**

------------------------------------------------------------------------

## 20. Special Card Choice Window

When the player has a usable Special Card, the current UI provides:

`CHOOSE YOUR ZERO`

Each valid pair is shown as a choice.

Example:

`10 + 10 + ✦`

`−20 points`

`BEST VALUE`

The player can also see how many owner turns remain.

The player can cancel instead of consuming the Special Card.

------------------------------------------------------------------------

## 21. Player Control

The Special Card is not automatically consumed.

The game can recommend the best target, but the player confirms it.

This is especially important when multiple pairs exist.

The player remains responsible for the strategic decision.

------------------------------------------------------------------------

## 22. Special Card Consumption

When the player confirms:

`10 + 10 + SPECIAL`

the Special Card is removed from active use.

The engine represents the Special Card's contribution as an internal
zero-group token associated with the two matching cards.

The resulting group contributes zero score.

The Special Card cannot be reused.

------------------------------------------------------------------------

## 23. Special Card Reset

After successful use:

-   Special Card lifetime is cleared.
-   Special Card acquisition state is cleared.
-   The pair becomes a zero group.
-   The score drops accordingly.
-   The Special Card is consumed.

This prevents one Special Card from producing multiple zero groups.

------------------------------------------------------------------------

## 24. AI Special Card Behavior

AI follows the same Special Card rules.

When AI has a usable Special Card:

1.  Find valid pairs.
2.  Rank them.
3.  Choose the highest-value target.
4.  Complete the pair.
5.  Continue its normal turn.

The current AI uses the best Special rank rather than randomly selecting
a pair.

------------------------------------------------------------------------

## 25. Special Card Count

The development discussion considered:

### 2 players

`1 Special Card`

### 3 players

`1 Special Card`

### 4 players

The discussion considered 1--2 cards.

However, the latest implementation currently configures:

`1 Special Card`

for four players.

This should be treated as the current implementation unless we
deliberately change the configuration.

------------------------------------------------------------------------

## 26. Why Special Cards Must Stay Rare

Too many Special Cards would make the game too easy.

If Special Cards become common:

-   pairs become less valuable,
-   waiting becomes less meaningful,
-   high cards become less dangerous,
-   normal draw/discard strategy loses importance.

The intended feeling is:

**rare + powerful + time-sensitive**

------------------------------------------------------------------------

# CARD AVAILABILITY & PACING

## 27. Problem Found During Testing

Testing showed that useful repeated ranks sometimes appeared too slowly.

The player could spend many turns waiting for one exact card.

This produced poor engagement:

> "Nothing useful is happening."

We therefore changed both card availability and draw selection behavior.

------------------------------------------------------------------------

## 28. Partial Second-Deck Strategy

The current V2.2 configuration for four players does not use a complete
second deck.

### Four-player, 7-card mode

`1 full deck + 25% second deck`

`52 + 13 = 65 normal cards`

### Four-player, 13-card mode

`1 full deck + 50% second deck`

`52 + 26 = 78 normal cards`

For fewer than four players, the current configuration uses one deck.

The partial second deck is generated as a shuffled subset of a full
second deck.

------------------------------------------------------------------------

## 29. Why We Avoid a Full Second Deck

Testing showed that a complete second deck could make the game finish
too quickly.

The fractional deck attempts to create a middle ground:

-   enough duplicate availability,
-   fewer dead turns,
-   longer decision-making,
-   fewer trivial groups,
-   less flooding of repeated cards.

The desired design target discussed during testing was approximately:

**5--10 minutes of meaningful play**, with roughly **7 minutes as a
preferred upper target**.

These are targets, not guaranteed match durations.

------------------------------------------------------------------------

## 30. K / Q / J / 10 Availability

A standard deck contains:

-   4 × 10
-   4 × J
-   4 × Q
-   4 × K

So there are:

**16 cards with value 10 per complete deck.**

However, 10, J, Q and K remain separate ranks.

The partial second deck contributes only the selected subset of cards.

Therefore the exact number of additional K/Q/J/10 cards depends on which
cards are selected into the partial deck.

------------------------------------------------------------------------

## 31. Physical Availability vs Draw Algorithm

Two separate concepts must not be confused.

### Physical availability

How many actual cards of a rank exist.

### Draw selection

Which available card the gameplay algorithm chooses.

The current V2.2 system uses a look-ahead draw strategy.

Therefore a player's perceived frequency can differ from a purely random
top-of-deck draw.

------------------------------------------------------------------------

## 32. Anti-Starvation Draw Brain

The V2.2 draw system keeps a genuinely shuffled deck but evaluates a
small look-ahead window.

Current look-ahead:

**9 cards**

Candidate cards are scored for usefulness.

Factors include:

-   score improvement,
-   pair creation,
-   group creation,
-   near-zero improvement,
-   dry-draw protection,
-   repeat balancing.

The purpose is not to guarantee the card the player wants.

It is to reduce long periods of meaningless draws.

------------------------------------------------------------------------

## 33. Pair Weight

If a candidate card matches one existing card in the player's hand, it
gets additional utility.

Example:

Hand:

`7 7 4 8 K`

Candidate:

`7`

The candidate can create a stronger group opportunity.

Therefore it is more useful than a completely unrelated card.

------------------------------------------------------------------------

## 34. Group Weight

If a candidate matches two cards already held, it is even more valuable.

Example:

Hand:

`7 7 7?`

If the candidate creates an immediate group opportunity, its utility is
strongly increased.

The draw algorithm therefore recognizes that a group-forming card is
more useful than a random unrelated card.

------------------------------------------------------------------------

## 35. Score-Improvement Weight

A candidate is evaluated by comparing:

`score before draw`

against:

`best score after draw`

A candidate that creates a meaningful reduction receives additional
utility.

This lets the system think beyond simple duplicate detection.

------------------------------------------------------------------------

## 36. Dry-Draw Protection

The game tracks unproductive stock draws using:

`dryDraws`

When the player repeatedly receives cards that provide no useful
improvement, the dry-draw count increases.

After the configured threshold, the draw system gradually increases the
chance of choosing useful candidates.

The current system begins soft protection around the third dry draw and
caps the protection.

This is intentionally **soft pity**, not guaranteed pity.

------------------------------------------------------------------------

## 37. Why Soft Pity Is Better

Bad implementation:

> Player wants 10 → always give 10.

That destroys randomness.

Better implementation:

> Player has experienced several dry draws → increase the chance of
> useful candidates.

The player still has uncertainty.

The system simply protects the experience from extreme dead streaks.

------------------------------------------------------------------------

# OPENING HAND BALANCE

## 38. Opening Opportunity Balancer

A player can start with:

`A 3 5 7 8 J K`

with no pair.

That can create a poor opening.

The V2.2 opening balancer checks opening hands.

If no duplicate rank exists, the system has a configured chance to
improve the opening opportunity.

Current chance:

**72%**

The mechanism searches the stock for a matching rank and swaps it with a
high-value opening card.

------------------------------------------------------------------------

## 39. Opening Balancer Philosophy

The purpose is:

**reduce dead openings**

not:

**give everyone a winning hand**

It should make the player feel:

> "I have something to work with."

not:

> "The game already gave me the answer."

------------------------------------------------------------------------

# HAND UX IMPROVEMENTS

## 40. Natural Hand Clustering

Cards are clustered by rank by default.

Example:

Raw order:

`7 3 7 K 3 8`

Natural clustered presentation:

`7 7 | 3 3 | K | 8`

The game does not automatically force rigid numeric sorting.

This makes pair opportunities easier to recognize.

------------------------------------------------------------------------

## 41. SORT Button

SORT is an explicit user action.

The player can toggle sorting when desired.

This prevents cards from constantly jumping around after every draw.

Design principle:

> **The player owns the hand layout.**

------------------------------------------------------------------------

## 42. Group Collapse / Expand

Completed zero groups can be collapsed into a compact stack.

Example:

`7 7 7`

can be represented as:

`7 ×3 → 0`

This saves space, especially in 13-card mode.

Interaction:

`Tap collapsed group → expand`

`Tap expanded group → collapse`

This was added because testing showed that users needed a clear way to
return an expanded group to its compact form.

------------------------------------------------------------------------

## 43. Score Preview

During discard selection, the UI can show:

`44 → 34`

This means:

> If the selected card is discarded, the optimized score becomes 34.

This reduces unnecessary mental arithmetic while keeping the strategic
decision with the player.

------------------------------------------------------------------------

## 44. Contextual Hints

Hints are shown when they are genuinely useful.

Examples:

If the visible discard completes a group:

`7♦ completes your group → ZERO!`

If Special Card is usable:

`Special Card ready — choose the pair that drops your count most.`

If Special Card is waiting:

`Special Card waiting — 2 owner turns remaining.`

If the player has a dry streak:

`Dry streak protection is active — watch for new opportunities.`

Generic hints are intentionally not rotated constantly because changing
text causes visual layout movement.

------------------------------------------------------------------------

# GAME TIMER

## 45. Match Timer

A match timer was added specifically for testing game duration.

The match stores:

`startedAt`

When the match ends:

`endedAt`

The display uses:

`MM:SS`

Example:

`03:42`

The timer updates once per second.

------------------------------------------------------------------------

## 46. Why the Timer Matters

The timer lets us measure:

-   match duration,
-   round duration,
-   whether the partial deck is too large,
-   whether Special Cards shorten matches too much,
-   whether anti-starvation makes games healthier,
-   whether 7-card games are too short,
-   whether 13-card games are too long.

This turns subjective testing into measurable balancing.

------------------------------------------------------------------------

# ROUND & SCORE LOGIC

## 47. SHOW

A player may SHOW when they believe their score is low enough.

SHOW ends the current round.

All players' hands are revealed.

Each hand is optimized using the normal group rules plus any valid
Special-created zero groups.

The resulting round score is added to cumulative match score.

------------------------------------------------------------------------

## 48. Cumulative Score

The game is based on lowest cumulative score.

Example:

Player A:

`Round 1 = 8`

`Round 2 = 14`

`Total = 22`

Player B:

`Round 1 = 12`

`Round 2 = 9`

`Total = 21`

Player B is currently ahead because 21 is lower.

------------------------------------------------------------------------

## 49. Target Score

The game uses a configurable target score.

Original recommended targets include:

-   100
-   200
-   500

The common test configuration uses:

**100**

The game ends when the match reaches its terminal target condition.

------------------------------------------------------------------------

# DECK MANAGEMENT

## 50. Deck Exhaustion

If the draw stock becomes empty:

1.  Preserve the current top discard.
2.  Take the remaining discard cards.
3.  Shuffle them.
4.  Use them as the new draw stock.

This prevents the game from becoming stuck.

------------------------------------------------------------------------

# ARCHITECTURE

## 51. Game Engine Principle

The game should not become UI-first logic.

Long-term architecture:

``` text
UI
 ↓
Game API
 ↓
Game Engine
 ↓
Rules Engine / Score Engine / Turn Engine
 ↓
GameState
```

The UI should visualize GameState.

AI should consume the same Game Engine.

Multiplayer should eventually use the same engine with
server-authoritative transport.

------------------------------------------------------------------------

## 52. AI Principle

AI must follow the same game rules as humans.

AI should use:

-   the same card values,
-   the same group rules,
-   the same Special Card rules,
-   the same turn structure,
-   the same score engine.

Difficulty should come from decision quality, not different rules.

------------------------------------------------------------------------

# SPECIAL CARD --- COMPLETE FLOW

## 53. Flow Diagram

``` text
DRAW SPECIAL CARD
        ↓
Check hand
        ↓
Is there a valid pair?
      /       YES    NO
     ↓      ↓
Find all    Keep Special
valid pairs in hand
     ↓      ↓
Calculate  Start/continue
score drop countdown
     ↓      ↓
Recommend  Search for
best target useful duplicate
     ↓      ↓
Player confirms
     ↓
Pair + Special
     ↓
ZERO GROUP
     ↓
Large score reduction
     ↓
Special consumed
```

If no pair appears before expiry:

``` text
SPECIAL
   ↓
WAIT
   ↓
4 → 3 → 2 → 1
   ↓
EXPIRE
   ↓
DISCARD
```

------------------------------------------------------------------------

# SPECIAL CARD TEST CASES

## 54. Basic Tests

Test:

-   Special Card appears.
-   Special Card can be held.
-   Special Card does not activate without a pair.
-   Special Card activates with exactly two matching cards.
-   Special Card disappears after use.
-   Resulting group scores zero.

------------------------------------------------------------------------

## 55. Multiple-Pair Tests

Test:

-   10/10 + 7/7 + Special.
-   K/K + 10/10 + Special.
-   J/J + Q/Q + Special.
-   Equal-value targets.
-   Three different valid pairs.

Verify that the highest-value pair is recommended.

------------------------------------------------------------------------

## 56. Timer Tests

Test:

-   Special received with no pair.
-   One owner turn passes.
-   Two owner turns pass.
-   Three owner turns pass.
-   Fourth owner turn reaches expiry.
-   Pair appears before expiry.
-   Timer stops progressing while usable.
-   Successfully used Special clears the timer.

------------------------------------------------------------------------

## 57. AI Tests

Test:

-   AI receives Special.
-   AI has no pair.
-   AI waits.
-   AI obtains a pair.
-   AI chooses highest-value pair.
-   AI consumes Special once.
-   AI cannot reuse the consumed Special.

------------------------------------------------------------------------

# BALANCE TESTING

## 58. Recommended Simulation Matrix

  Players     Hand   Normal Cards   Special
  --------- ------ -------------- ---------
  2              7             52         1
  3              7             52         1
  4              7             65         1
  2             13             52         1
  3             13             52         1
  4             13             78         1

Track thousands of games where possible.

------------------------------------------------------------------------

## 59. Metrics to Track

Track:

-   average match duration,
-   average rounds,
-   average Special Cards acquired,
-   Special activation rate,
-   Special expiry rate,
-   average Special score reduction,
-   average Special time-to-use,
-   average dry-draw streak,
-   average groups created,
-   SHOW frequency,
-   K/Q/J/10 frequency,
-   deck exhaustion,
-   winner distribution.

------------------------------------------------------------------------

## 60. Special Card Health Metrics

### Activation rate

`activated / acquired`

### Expiry rate

`expired / acquired`

### Average reduction

Average score reduction produced by Special Card.

### Time to use

Owner turns from acquisition to activation.

### Dead-card time

Owner turns spent with an unusable Special Card.

These metrics tell us whether the mechanic is too strong, too weak, too
rare or too common.

------------------------------------------------------------------------

# IMPORTANT DISTINCTIONS

## 61. Current Implementation vs Earlier Discussion

### Current implementation includes

-   Special Card.
-   Special arrival animation.
-   Special target detection.
-   Highest-value target recommendation.
-   Player choice UI.
-   Special consumption.
-   Zero-group representation.
-   Four-owner-turn lifetime.
-   Expiry to discard.
-   Countdown display.
-   Urgent countdown animation.
-   AI Special Card use.
-   Fractional second-deck availability.
-   Nine-card draw look-ahead.
-   Dry-draw protection.
-   Opening opportunity balancer.
-   Natural rank clustering.
-   Explicit SORT.
-   Group collapse/expand.
-   Score preview.
-   Match timer.
-   Contextual hints.

### Earlier discussion ideas that should not be assumed to be implemented

-   Automatically giving two Special Cards to every four-player game.
-   Arbitrary sequence-based Special Card combinations.
-   Universal wildcard behavior.
-   Guaranteed delivery of a desired rank.
-   Permanent Special Card holding.
-   Converting 10/J/Q/K into one rank.

------------------------------------------------------------------------

# FINAL GAME-BRAIN MODEL

## 62. Per-Turn Decision Engine

Every turn should encourage the player to think:

1.  What is my current optimized score?
2.  What is the visible discard?
3.  Does it create or extend a useful rank group?
4.  Should I take the known discard or risk the stock?
5.  Which ranks am I currently pursuing?
6.  Which high-value cards should I remove?
7.  Do I have a Special Card?
8.  If yes, is it usable?
9.  If usable, which pair gives the biggest reduction?
10. If unusable, how many owner turns remain?
11. Should I pursue a duplicate for the Special Card?
12. Should I abandon the Special Card?
13. Is my current score low enough to SHOW?
14. What might the opponents be collecting?

This is the strategic brain we are trying to build.

------------------------------------------------------------------------

## 63. The Two Main Protection Systems

### Normal-card protection

``` text
Random deck
    +
9-card look-ahead
    +
utility scoring
    +
dry-draw protection
```

Purpose:

**Prevent long boring periods without guaranteeing the desired card.**

### Special-card protection

``` text
Special Card
    +
valid-pair detection
    +
best-value recommendation
    +
4-turn lifetime
```

Purpose:

**Create an additional strategic opportunity while preventing the card
from becoming permanent dead weight.**

------------------------------------------------------------------------

## 64. The Complete Experience

The intended gameplay loop is:

``` text
DRAW
 ↓
OBSERVE
 ↓
EVALUATE SCORE
 ↓
LOOK FOR PAIRS
 ↓
LOOK FOR GROUPS
 ↓
CHECK DISCARD
 ↓
CHECK SPECIAL
 ↓
MAKE DECISION
 ↓
DISCARD
 ↓
SCORE UPDATE
 ↓
SPECIAL TIMER UPDATE
 ↓
SHOW OR CONTINUE
```

The player should feel that every turn gives them something meaningful
to evaluate.

------------------------------------------------------------------------

# 65. Product Philosophy

The game should still be explainable in approximately one minute:

> **Pick a card. Keep useful cards. Make matching groups. Reduce your
> score. Show when you think you are low. Lowest score wins.**

Underneath that simple explanation, the game should provide:

-   probability,
-   risk,
-   memory,
-   opportunity recognition,
-   score optimization,
-   opponent observation,
-   Special Card timing,
-   discard strategy,
-   urgency,
-   and meaningful choice.

The Special Card should strengthen this philosophy rather than replace
it.

The ideal player feeling is:

> **"I always have something to think about."**

That is the core experience Zero Count is being designed around.
