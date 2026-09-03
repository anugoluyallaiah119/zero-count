import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/analytics/analytics_service.dart';
import '../../ui/zc_button.dart';
import '../../ui/zc_playing_card.dart';
import '../../ui/zc_theme.dart';
import '../player/profile_repository.dart';
import 'game_screen.dart';

/// Choose Game Type — pixel-matched to the Choose_game mockup: two big mode
/// cards (Quick/Classic) with card fans and check badge, game-rules strip,
/// player-count tiles, target-score tiles and gold CONTINUE.
///
/// Entered from the Home PLAY tiles with the tapped mode preselected;
/// CONTINUE starts the match setup (G1.6) with that mode.
class ChooseGameScreen extends ConsumerStatefulWidget {
  const ChooseGameScreen({super.key, this.initialMode = 'quick'});

  final String initialMode;

  @override
  ConsumerState<ChooseGameScreen> createState() => _ChooseGameScreenState();
}

class _ChooseGameScreenState extends ConsumerState<ChooseGameScreen> {
  late bool _classic = widget.initialMode == 'classic';
  int _players = 4;
  int _target = 100;

  void _continue() {
    final mode = _classic ? 'classic' : 'quick';
    final pCount = _players == 0 ? 4 : _players;
    final tScore = _target <= 0 ? 100 : _target;
    ref.read(analyticsServiceProvider).track('game_opened', {
      'mode': mode,
      'players': pCount,
      'target': tScore,
    });
    context.push('/game', extra: GameArgs(mode: mode, players: pCount, target: tScore));
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider).valueOrNull;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _ChooseHeader(coins: p?.coins ?? 0, gems: p?.gems ?? 0),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ModeCard(
                              key: const Key('chooseQuick'),
                              selected: !_classic,
                              fill: ZcColors.panelPurple,
                              border: ZcColors.neonPurple,
                              cards: const [
                                ('2', ZcSuit.clubs, 2),
                                ('5', ZcSuit.hearts, 5),
                                ('K', ZcSuit.diamonds, 10),
                              ],
                              title: 'QUICK PLAY',
                              cardsLabel: '7 Cards',
                              desc: 'Fast, fun and dynamic matches with 7 cards.',
                              time: '5 - 10 min',
                              badge: '⚡ Best for quick fun!',
                              onTap: () => setState(() => _classic = false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModeCard(
                              key: const Key('chooseClassic'),
                              selected: _classic,
                              fill: ZcColors.panelDeepBlue,
                              border: ZcColors.neonBlue,
                              cards: const [
                                ('J', ZcSuit.spades, 10),
                                ('Q', ZcSuit.hearts, 10),
                                ('K', ZcSuit.diamonds, 10),
                              ],
                              title: 'CLASSIC PLAY',
                              cardsLabel: '13 Cards',
                              desc: 'The classic experience with more cards, more strategy!',
                              time: '10 - 20 min',
                              badge: '★ More cards, more strategy!',
                              onTap: () => setState(() => _classic = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _RulesPanel(),
                      const SizedBox(height: 16),
                      _playersPanel(),
                      const SizedBox(height: 16),
                      _targetPanel(),
                      const SizedBox(height: 18),
                      ZcGoldButton(
                        key: const Key('chooseContinue'),
                        label: 'CONTINUE',
                        onPressed: _continue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playersPanel() {
    Widget tile(String label, IconData icon, bool selected, VoidCallback onTap,
        {Key? key}) {
      return Expanded(
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? ZcColors.gemPurple.withValues(alpha: 0.3)
                  : ZcColors.panelInput.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? ZcColors.neonPurple
                    : const Color(0x2EFFFFFF),
                width: selected ? 1.8 : 1.1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: ZcColors.neonPurple.withValues(alpha: 0.4),
                          blurRadius: 12)
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(children: [
                    Icon(icon, color: Colors.white, size: 26),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            color: selected
                                ? ZcColors.gold
                                : ZcColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
                if (selected)
                  const Positioned(
                    top: 0,
                    right: 4,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: ZcColors.gemPurple,
                      child: Icon(Icons.check_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT PLAYERS', style: ZcText.heading(13)),
        const SizedBox(height: 10),
        Row(children: [
          tile('2 PLAYERS', Icons.group_rounded, _players == 2,
              () => setState(() => _players = 2),
              key: const Key('players2')),
          tile('3 PLAYERS', Icons.groups_rounded, _players == 3,
              () => setState(() => _players = 3),
              key: const Key('players3')),
          tile('4 PLAYERS', Icons.groups_2_rounded, _players == 4,
              () => setState(() => _players = 4),
              key: const Key('players4')),
          tile('RANDOM', Icons.shuffle_rounded, _players == 0,
              () => setState(() => _players = 0),
              key: const Key('playersRandom')),
        ]),
      ],
    );
  }

  Widget _targetPanel() {
    Widget tile(String top, String bottom, bool selected, VoidCallback onTap,
        {Key? key, IconData? icon}) {
      return Expanded(
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? ZcColors.gemPurple.withValues(alpha: 0.3)
                  : ZcColors.panelInput.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? ZcColors.neonPurple
                    : const Color(0x2EFFFFFF),
                width: selected ? 1.8 : 1.1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(children: [
                    if (icon != null)
                      Icon(icon, color: ZcColors.textSecondary, size: 18)
                    else
                      Text(top,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : ZcColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(bottom,
                        style: TextStyle(
                            color: selected
                                ? ZcColors.gold
                                : ZcColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (selected)
                  const Positioned(
                    top: 0,
                    right: 4,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: ZcColors.gemPurple,
                      child: Icon(Icons.check_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('TARGET SCORE', style: ZcText.heading(13)),
          const SizedBox(width: 6),
          Text('(Lowest score wins!)', style: ZcText.body(11)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final v in [100, 200, 500, 1000])
            tile('$v', 'Points', _target == v,
                () => setState(() => _target = v),
                key: Key('target$v')),
          tile('', 'Custom', _target == -1,
              () => setState(() => _target = -1),
              key: const Key('targetCustom'), icon: Icons.edit_rounded),
        ]),
      ],
    );
  }
}

class _ChooseHeader extends StatelessWidget {
  const _ChooseHeader({required this.coins, required this.gems});

  final int coins;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _backButton(context),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHOOSE GAME TYPE',
                    style: ZcText.heading(16).copyWith(letterSpacing: 0.5)),
                Text('Pick your favorite way to play!',
                    style: ZcText.body(11.5)),
              ],
            ),
          ),
          _pill('assets/art/coin.png', '$coins'),
          const SizedBox(width: 6),
          _pill('assets/art/gem.png', '$gems'),
          const SizedBox(width: 6),
          const CircleAvatar(
            radius: 15,
            backgroundColor: Color(0x2EFFFFFF),
            child: Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 17),
          ),
        ],
      ),
    );
  }

  static Widget _backButton(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.pop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x990D0330),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x40FFFFFF), width: 1.1),
            ),
            child: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 24),
          ),
        ),
      );

  static Widget _pill(String asset, String value) => Container(
        padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
        decoration: BoxDecoration(
          color: const Color(0x990D0330),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0x33FFFFFF), width: 1),
        ),
        child: Row(children: [
          Image.asset(asset, width: 17, height: 17),
          const SizedBox(width: 3),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 2),
          const CircleAvatar(
            radius: 7,
            backgroundColor: ZcColors.onlineGreen,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 11),
          ),
        ]),
      );
}

/// Big selectable mode card with card fan + stats + bottom badge pill.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.selected,
    required this.fill,
    required this.border,
    required this.cards,
    required this.title,
    required this.cardsLabel,
    required this.desc,
    required this.time,
    required this.badge,
    required this.onTap,
  });

  final bool selected;
  final Color fill;
  final Color border;
  final List<(String, ZcSuit, int)> cards;
  final String title;
  final String cardsLabel;
  final String desc;
  final String time;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 30),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: selected
                      ? border
                      : border.withValues(alpha: 0.35),
                  width: selected ? 2.2 : 1.3),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: border.withValues(alpha: 0.5),
                          blurRadius: 22,
                          spreadRadius: 1)
                    ]
                  : null,
            ),
            child: Column(
              children: [
                ZcCardFan(cards: cards, cardWidth: 46, overlap: 0.6,
                    fanAngle: 0.12),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6)),
                Text(cardsLabel,
                    style: const TextStyle(
                        color: ZcColors.gold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(desc,
                    textAlign: TextAlign.center,
                    style: ZcText.body(10.5, color: Colors.white)
                        .copyWith(height: 1.35)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0x55000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    _statRow(Icons.groups_rounded, 'Players', '2 - 4'),
                    const SizedBox(height: 7),
                    Row(children: [
                      const Icon(Icons.schedule_rounded,
                          color: ZcColors.gemPurple, size: 15),
                      const SizedBox(width: 6),
                      Text('Game Time', style: ZcText.body(11)),
                      const Spacer(),
                      Flexible(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: time.replaceAll(' min', ''),
                                style: const TextStyle(
                                    color: ZcColors.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                            TextSpan(
                                text: ' min',
                                style: ZcText.body(10.5,
                                    color: ZcColors.gold)),
                          ]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ]),
                ),
              ],
            ),
          ),
          if (selected)
            const Positioned(
              top: -8,
              right: 10,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: ZcColors.gemPurple,
                child: Icon(Icons.check_rounded,
                    color: Colors.white, size: 17),
              ),
            ),
          Positioned(
            bottom: -13,
            left: 10,
            right: 10,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 1.3),
                ),
                child: Text(badge,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: ZcColors.gemPurple, size: 15),
      const SizedBox(width: 6),
      Text(label, style: ZcText.body(11)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              color: ZcColors.gold,
              fontSize: 12.5,
              fontWeight: FontWeight.w800)),
    ]);
  }
}

/// GAME RULES strip — five mini tiles, all vector-rendered.
class _RulesPanel extends StatelessWidget {
  const _RulesPanel();

  @override
  Widget build(BuildContext context) {
    Widget tile(Widget visual, Widget caption, {bool danger = false}) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: ZcColors.panelInput.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: danger
                    ? ZcColors.errorRed
                    : const Color(0x2EFFFFFF),
                width: danger ? 1.6 : 1.1),
          ),
          child: Column(children: [
            SizedBox(height: 52, child: Center(child: visual)),
            const SizedBox(height: 8),
            caption,
          ]),
        ),
      );
    }

    Text cap(List<TextSpan> spans) => Text.rich(
          TextSpan(children: spans),
          textAlign: TextAlign.center,
          style: ZcText.body(9.5, color: Colors.white).copyWith(height: 1.3),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('GAME RULES', style: ZcText.heading(13)),
            const SizedBox(width: 6),
            Flexible(
              child: Text('(Same for both modes)',
                  overflow: TextOverflow.ellipsis, style: ZcText.body(10.5)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(
                Image.asset('assets/art/icon_aces.png', height: 48),
                cap([
                  const TextSpan(text: '3 or more cards with the same number = '),
                  TextSpan(
                      text: 'ZERO',
                      style: ZcText.body(9.5,
                          color: ZcColors.gold, weight: FontWeight.w800)),
                ]),
              ),
              tile(
                const ZcPlayingCard(
                    rank: 'A', suit: ZcSuit.spades, value: 1, width: 34),
                cap([
                  TextSpan(
                      text: 'A = 1',
                      style: ZcText.body(10.5,
                          color: ZcColors.gold, weight: FontWeight.w800)),
                ]),
              ),
              tile(
                const ZcCardFan(
                  cards: [
                    ('J', ZcSuit.clubs, 10),
                    ('Q', ZcSuit.hearts, 10),
                    ('K', ZcSuit.clubs, 10),
                  ],
                  cardWidth: 24,
                  overlap: 0.55,
                ),
                cap([
                  TextSpan(
                      text: 'J, Q, K = 10',
                      style: ZcText.body(9.5,
                          color: ZcColors.gold, weight: FontWeight.w800)),
                ]),
              ),
              tile(
                Stack(alignment: Alignment.center, children: [
                  const ZcCardFan(
                    cards: [
                      ('3', ZcSuit.clubs, 3),
                      ('4', ZcSuit.spades, 4),
                      ('5', ZcSuit.hearts, 5),
                    ],
                    cardWidth: 24,
                    overlap: 0.55,
                  ),
                  const Icon(Icons.block_rounded,
                      color: ZcColors.errorRed, size: 40),
                ]),
                cap([
                  const TextSpan(text: 'Sequences are '),
                  TextSpan(
                      text: 'NOT',
                      style: ZcText.body(9.5,
                          color: ZcColors.errorRed, weight: FontWeight.w800)),
                  const TextSpan(text: ' allowed'),
                ]),
                danger: true,
              ),
              tile(
                const Icon(Icons.flag_rounded,
                    color: ZcColors.gemPurple, size: 38),
                cap([
                  const TextSpan(text: 'Lowest count '),
                  TextSpan(
                      text: 'wins!',
                      style: ZcText.body(9.5,
                          color: ZcColors.gold, weight: FontWeight.w800)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
