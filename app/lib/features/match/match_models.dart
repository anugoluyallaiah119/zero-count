/// JSON models for the server-authoritative live match (M1.7).
///
/// Mirrors the backend contract in MatchService:
///   publicView: {phase, round, currentPlayerIdx, stockSize, topDiscard,
///                over, players:[{id, cards, matchScore}]}
///   handView:   {hand:[{id, rank, suit, value}]}
///   topic msg:  {type:"state", state:publicView} or individual events
///               {type: round_started|drew_stock|drew_discard|discarded|
///                turn_passed|showed|stock_recycled|round_ended|match_ended|
///                stalemate_forced|state, ...}
library;

import '../../shared/widgets/mini_card.dart';

/// One card as seen over the wire ({id, rank, suit, value}).
class LiveCard {
  const LiveCard(
      {required this.id,
      required this.rank,
      required this.suit,
      required this.value});

  final int id;
  final String rank; // 'A', '2'…'10', 'J', 'Q', 'K'
  final CardSuit suit;
  final int value;

  factory LiveCard.fromJson(Map<String, dynamic> j) => LiveCard(
        id: (j['id'] as num).toInt(),
        rank: j['rank'] as String,
        suit: CardSuit.values.byName((j['suit'] as String).toLowerCase()),
        value: (j['value'] as num).toInt(),
      );
}

/// A seat in the public view: only the card COUNT is visible (hidden info).
class LiveSeat {
  const LiveSeat(
      {required this.id, required this.cards, required this.matchScore});

  final String id; // user UUID string
  final int cards;
  final int matchScore;

  factory LiveSeat.fromJson(Map<String, dynamic> j) => LiveSeat(
        id: j['id'] as String,
        cards: (j['cards'] as num).toInt(),
        matchScore: (j['matchScore'] as num).toInt(),
      );
}

/// Immutable snapshot of everything the live screen renders.
class LiveMatchState {
  const LiveMatchState({
    required this.code,
    required this.connected,
    required this.phase,
    required this.round,
    required this.currentPlayerIdx,
    required this.stockSize,
    required this.topDiscard,
    required this.over,
    required this.seats,
    required this.myHand,
    required this.selectedCardId,
    required this.lastEvents,
    required this.lastSeq,
    this.error,
    this.roundResult,
    this.matchResult,
  });

  factory LiveMatchState.initial(String code) => LiveMatchState(
        code: code,
        connected: false,
        phase: 'LOBBY',
        round: 0,
        currentPlayerIdx: -1,
        stockSize: 0,
        topDiscard: null,
        over: false,
        seats: const [],
        myHand: const [],
        selectedCardId: null,
        lastEvents: const [],
        lastSeq: 0,
      );

  final String code;
  final bool connected;

  /// M1.8: true when the socket dropped AFTER a successful session — the UI
  /// shows a "reconnecting" banner over the frozen table instead of the
  /// initial spinner. The replay-on-connect resync heals any gap.
  bool get reconnecting => !connected && lastSeq > 0;
  final String phase; // DRAW, DISCARD, POST_TURN, ROUND_END, MATCH_END…
  final int round;
  final int currentPlayerIdx;
  final int stockSize;
  final LiveCard? topDiscard;
  final bool over;
  final List<LiveSeat> seats;
  final List<LiveCard> myHand;
  final int? selectedCardId;
  final List<String> lastEvents; // human-readable recent events
  final int lastSeq;
  final String? error;
  final Map<String, dynamic>? roundResult;
  final Map<String, dynamic>? matchResult;

  /// Index of the local player in [seats], or -1 when not seated yet.
  int mySeatIndex(String myUserId) {
    for (var i = 0; i < seats.length; i++) {
      if (seats[i].id == myUserId) return i;
    }
    return -1;
  }

  /// Current count of my hand (V1 scoring: sum of card values, ZERO groups
  /// are server-side; here we show the raw count preview like the offline UI).
  int get myCount => myHand.fold(0, (sum, c) => sum + c.value);

  LiveMatchState copyWith({
    bool? connected,
    String? phase,
    int? round,
    int? currentPlayerIdx,
    int? stockSize,
    LiveCard? Function()? topDiscard,
    bool? over,
    List<LiveSeat>? seats,
    List<LiveCard>? myHand,
    int? Function()? selectedCardId,
    List<String>? lastEvents,
    int? lastSeq,
    String? Function()? error,
    Map<String, dynamic>? Function()? roundResult,
    Map<String, dynamic>? Function()? matchResult,
  }) =>
      LiveMatchState(
        code: code,
        connected: connected ?? this.connected,
        phase: phase ?? this.phase,
        round: round ?? this.round,
        currentPlayerIdx: currentPlayerIdx ?? this.currentPlayerIdx,
        stockSize: stockSize ?? this.stockSize,
        topDiscard: topDiscard != null ? topDiscard() : this.topDiscard,
        over: over ?? this.over,
        seats: seats ?? this.seats,
        myHand: myHand ?? this.myHand,
        selectedCardId:
            selectedCardId != null ? selectedCardId() : this.selectedCardId,
        lastEvents: lastEvents ?? this.lastEvents,
        lastSeq: lastSeq ?? this.lastSeq,
        error: error != null ? error() : this.error,
        roundResult: roundResult != null ? roundResult() : this.roundResult,
        matchResult: matchResult != null ? matchResult() : this.matchResult,
      );

  /// Fold a public view broadcast into the snapshot.
  LiveMatchState applyPublicView(Map<String, dynamic> v) => copyWith(
        phase: v['phase'] as String? ?? phase,
        round: (v['round'] as num?)?.toInt() ?? round,
        currentPlayerIdx:
            (v['currentPlayerIdx'] as num?)?.toInt() ?? currentPlayerIdx,
        stockSize: (v['stockSize'] as num?)?.toInt() ?? stockSize,
        topDiscard: () => v['topDiscard'] == null
            ? null
            : LiveCard.fromJson(v['topDiscard'] as Map<String, dynamic>),
        over: v['over'] as bool? ?? over,
        seats: (v['players'] as List? ?? [])
            .map((p) => LiveSeat.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
