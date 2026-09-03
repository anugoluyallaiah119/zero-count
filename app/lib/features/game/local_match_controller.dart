import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/ai.dart';
import '../../engine/model.dart';
import '../../engine/scoring.dart';
import '../../engine/session.dart';
import '../../shared/analytics/analytics_service.dart';
import 'play_area_theme.dart';

/// How the player's hand is laid out (V1 SORT toggle).
enum SortMode { byRank, grouped }

/// UI-facing snapshot of a local offline match.
class LocalMatchState {
  const LocalMatchState({
    required this.session,
    required this.names,
    required this.difficulty,
    required this.selectedCardId,
    required this.sortMode,
    required this.aiThinking,
    required this.lastEvents,
    required this.playAreaTheme,
    this.roundResult,
    this.matchResult,
  });

  final GameSession session;
  final List<String> names; // names[0] = 'You'
  final DifficultyProfile difficulty;
  final int? selectedCardId;
  final SortMode sortMode;
  final bool aiThinking;
  final List<GameEvent> lastEvents;
  final PlayAreaTheme playAreaTheme;

  /// Non-null while the round-end overlay is up: per-player counts + totals.
  final RoundEnded? roundResult;

  /// Non-null when the match is over.
  final MatchEnded? matchResult;

  bool get isHumanTurn => session.currentPlayerIdx == 0 && !session.isOver;

  PlayerState get you => session.players[0];

  /// Current live count of the human hand (score preview, G1.5).
  int get yourCount => ScoringEngine.count(you.hand.cards);

  LocalMatchState copyWith({
    GameSession? session,
    int? Function()? selectedCardId,
    SortMode? sortMode,
    bool? aiThinking,
    List<GameEvent>? lastEvents,
    PlayAreaTheme? playAreaTheme,
    RoundEnded? Function()? roundResult,
    MatchEnded? Function()? matchResult,
  }) =>
      LocalMatchState(
        session: session ?? this.session,
        names: names,
        difficulty: difficulty,
        selectedCardId:
            selectedCardId != null ? selectedCardId() : this.selectedCardId,
        sortMode: sortMode ?? this.sortMode,
        aiThinking: aiThinking ?? this.aiThinking,
        lastEvents: lastEvents ?? this.lastEvents,
        playAreaTheme: playAreaTheme ?? this.playAreaTheme,
        roundResult: roundResult != null ? roundResult() : this.roundResult,
        matchResult: matchResult != null ? matchResult() : this.matchResult,
      );
}

/// Offline single-player match vs 1–3 AI opponents (G1.6), driven by the
/// E3.6 Dart engine. The human is seat 0; every AI seat has an AiDecider
/// whose seat aggression matches V1. AI turns run on short timers so the
/// table stays watchable.
class LocalMatchController extends Notifier<LocalMatchState?> {
  static const _aiStepDelay = Duration(milliseconds: 1400);
  static const _aiNames = ['Rahul', 'Sneha', 'Karan'];

  Timer? _aiTimer;

  @override
  LocalMatchState? build() {
    ref.onDispose(() => _aiTimer?.cancel());
    return null; // no match until the player picks a mode
  }

  /// Start a fresh match. [players] is total seats (2–4, human included).
  void newMatch(GameConfig config, DifficultyProfile difficulty,
      {int? seed}) {
    _aiTimer?.cancel();
    // L1.3 funnel: match_started (with difficulty + seat count).
    final difficultyLabel = identical(difficulty, DifficultyProfile.easy)
        ? 'easy'
        : identical(difficulty, DifficultyProfile.hard)
            ? 'hard'
            : 'normal';
    ref.read(analyticsServiceProvider).track('match_started', {
      'difficulty': difficultyLabel,
      'players': config.players,
      'target': config.target,
    });
    final ids = List.generate(config.players, (i) => i == 0 ? 'you' : 'ai$i');
    final session = GameSession(
        config, ids, seed ?? DateTime.now().millisecondsSinceEpoch);
    state = LocalMatchState(
      session: session,
      names: ['You', ..._aiNames.take(config.players - 1)],
      difficulty: difficulty,
      selectedCardId: null,
      sortMode: SortMode.byRank,
      aiThinking: false,
      lastEvents: session.eventLog.isEmpty
          ? const []
          : [session.eventLog.last],
      playAreaTheme: ref.read(equippedThemeProvider),
    );
    _maybeRunAi();
  }

  // ---------- human intents ----------

  void selectCard(int cardId) {
    final s = state;
    if (s == null || !s.isHumanTurn) return;
    state = s.copyWith(selectedCardId: () => s.selectedCardId == cardId ? null : cardId);
  }

  void toggleSort() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
        sortMode: s.sortMode == SortMode.byRank
            ? SortMode.grouped
            : SortMode.byRank);
  }

  /// DRAW phase: draw from stock.
  void drawStock() => _humanMove(DrawStock());

  /// DRAW phase: take the visible discard.
  void drawDiscard() => _humanMove(DrawDiscard());

  /// DISCARD phase: discard the selected card.
  void discardSelected() {
    final s = state;
    if (s == null || s.selectedCardId == null) return;
    final card = s.you.hand.cards
        .where((c) => c.id == s.selectedCardId)
        .firstOrNull;
    if (card == null) return;
    _humanMove(Discard(card));
  }

  /// POST window: declare SHOW.
  void show() => _humanMove(Show());

  /// POST window: end turn without showing.
  void endTurn() {
    final s = state;
    if (s == null || !s.isHumanTurn || s.session.phase != Phase.post) return;
    _apply(s.session.passTurn());
  }

  void _humanMove(Move move) {
    final s = state;
    if (s == null || !s.isHumanTurn) return;
    if (!s.session.isLegal('you', move)) return;
    _apply(s.session.apply('you', move));
  }

  // ---------- shared event handling ----------

  void _apply(List<GameEvent> events) {
    final s = state;
    if (s == null || events.isEmpty) return;
    RoundEnded? roundResult = s.roundResult;
    MatchEnded? matchResult = s.matchResult;
    int? selected = s.selectedCardId;
    for (final e in events) {
      if (e is Discarded && s.session.currentPlayerIdx == 0) {
        selected = null; // selection consumed
      }
      if (e is RoundEnded) roundResult = e;
      if (e is MatchEnded) {
        matchResult = e;
        // L1.3 funnel: match_completed with winner + rounds played.
        ref.read(analyticsServiceProvider).track('match_completed', {
          'won': e.winnerId == 'you',
          'round': s.session.round,
        });
      }
    }
    state = s.copyWith(
      lastEvents: events,
      selectedCardId: () => selected,
      roundResult: () => roundResult,
      matchResult: () => matchResult,
    );
    _maybeRunAi();
  }

  /// Continue to the next round from the round-end overlay.
  void nextRound() {
    final s = state;
    if (s == null || s.roundResult == null || s.matchResult != null) return;
    state = s.copyWith(roundResult: () => null);
    _maybeRunAi();
  }

  /// Abandon the current match (leaving the screen, rematch).
  void stopIfAny() {
    _aiTimer?.cancel();
    state = null;
  }

  // ---------- AI loop ----------

  void _maybeRunAi() {
    final s = state;
    if (s == null) return;
    if (s.session.isOver ||
        s.roundResult != null ||
        s.session.currentPlayerIdx == 0) {
      // Back to the human (or paused) — clear the thinking indicator.
      if (s.aiThinking) state = s.copyWith(aiThinking: false);
      return;
    }
    state = s.copyWith(aiThinking: true);
    _aiTimer?.cancel();
    _aiTimer = Timer(_aiStepDelay, _aiStep);
  }

  void _aiStep() {
    final s = state;
    if (s == null || s.session.isOver || s.session.currentPlayerIdx == 0) {
      if (s != null && s.aiThinking) {
        state = s.copyWith(aiThinking: false);
      }
      return;
    }
    final session = s.session;
    final idx = session.currentPlayerIdx;
    final player = session.players[idx];
    final ai = AiDecider.of(s.difficulty, idx);

    List<GameEvent> events;
    switch (session.phase) {
      case Phase.draw:
        final top = session.topDiscard;
        final move = (top != null && ai.shouldTakeDiscard(player.hand, top))
            ? DrawDiscard()
            : DrawStock();
        events = session.apply(player.playerId, move);
        _apply(events);
        return; // next AI step on a fresh timer
      case Phase.discard:
        events =
            session.apply(player.playerId, Discard(ai.chooseDiscard(player.hand)));
      case Phase.post:
        events = ai.shouldShow(player.hand, session.config.handSize)
            ? session.apply(player.playerId, Show())
            : session.passTurn();
      default:
        return;
    }
    _apply(events);
  }
}

final localMatchProvider =
    NotifierProvider<LocalMatchController, LocalMatchState?>(
        LocalMatchController.new);
