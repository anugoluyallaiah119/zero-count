import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_header.dart';
import '../../ui/zc_playing_card.dart';
import '../../ui/zc_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/avatar_catalog.dart';
import '../player/profile_repository.dart';
import '../room/lobby_screen.dart';
import '../room/room_repository.dart';

/// Countdown — pixel-matched to the Trigger_game_from_room mockup: carnival
/// banner with the glowing countdown ring, player tiles, mode stats strip,
/// rules reminder, YOUR CARDS preview fan and the GAME STARTING… bar.
///
/// Shown after the host taps START GAME; auto-navigates to the live match
/// when the timer reaches zero.
class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key, required this.code, this.seconds = 15});

  final String code;

  /// Countdown length in seconds (15 per mockup; tests pass less).
  final int seconds;

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends ConsumerState<CountdownScreen> {
  Timer? _timer;
  late int _left;

  @override
  void initState() {
    super.initState();
    _left = widget.seconds;
    Future.microtask(
        () => ref.read(lobbyProvider.notifier).watch(widget.code));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        context.pushReplacement('/match/${widget.code}');
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _leave() async {
    _timer?.cancel();
    await ref.read(lobbyProvider.notifier).leave();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyProvider);
    final myId = ref.watch(authControllerProvider).userId;
    final p = ref.watch(profileProvider).valueOrNull;
    final lb = lobby;
    final host =
        lb?.members.where((m) => m.userId == lb.hostId).firstOrNull;
    final classic = (lobby?.handSize ?? 13) == 13;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header: room name + code + pills (same chrome as lobby).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  const ZcBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text("${host?.displayName ?? 'Room'}'s Room",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ZcText.heading(16)),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.edit_rounded,
                              color: ZcColors.gemPurple, size: 14),
                        ]),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: widget.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Room code copied')));
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(children: [
                              Text('Room Code: ', style: ZcText.body(11.5)),
                              Text(widget.code,
                                  style: ZcText.body(11.5,
                                          color: Colors.white,
                                          weight: FontWeight.w800)
                                      .copyWith(letterSpacing: 1)),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy_rounded,
                                  color: ZcColors.textSecondary, size: 12),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(children: [
                      ZcCurrencyPill(
                          asset: 'assets/art/coin.png',
                          value: '${p?.coins ?? 0}'),
                      const SizedBox(width: 6),
                      ZcCurrencyPill(
                          asset: 'assets/art/gem.png',
                          value: '${p?.gems ?? 0}'),
                      const SizedBox(width: 6),
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(0x2EFFFFFF),
                        child: Icon(Icons.settings_rounded,
                            color: Colors.white, size: 17),
                      ),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _countdownBanner(classic),
                      const SizedBox(height: 14),
                      _playerTiles(lobby, myId),
                      const SizedBox(height: 14),
                      _statsStrip(lobby, classic),
                      const SizedBox(height: 14),
                      _rulesStrip(),
                      const SizedBox(height: 14),
                      _yourCards(classic),
                      const SizedBox(height: 14),
                      Row(children: [
                        _outlineAction(
                          key: const Key('leaveRoomButton'),
                          icon: Icons.logout_rounded,
                          label: 'LEAVE ROOM',
                          color: ZcColors.neonPink,
                          onTap: _leave,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: ZcColors.goldGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_rounded,
                                    color: ZcColors.goldText, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text('GAME STARTING...',
                                            style: ZcText.display(14,
                                                color: ZcColors.goldText)),
                                        Text('Please wait',
                                            style: ZcText.body(9.5,
                                                color: ZcColors.goldText)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _outlineAction(
                          key: const Key('chatButton'),
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'CHAT',
                          color: ZcColors.gemPurple,
                          onTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                            content: const Text(
                                'Stickers & emotes arrive with the social update'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: ZcColors.panelPurple,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          )),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lightbulb_rounded,
                                color: ZcColors.gemPurple, size: 15),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                  'Tip: Plan your moves and beat your opponents!',
                                  style: ZcText.body(11)),
                            ),
                          ],
                        ),
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

  /// Banner with the glowing countdown ring on carnival art.
  Widget _countdownBanner(bool classic) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: ZcColors.panelDeepBlue.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.62,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.0, 0.4],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Image.asset('assets/art/banner_carnival.png',
                    fit: BoxFit.cover, height: double.infinity),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Image.asset('assets/art/mask_carnival.png',
                  height: 150),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xB30D0330),
                    borderRadius: BorderRadius.circular(11),
                    border:
                        Border.all(color: const Color(0x40FFFFFF), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.style_rounded,
                        color: ZcColors.drawBlue, size: 14),
                    const SizedBox(width: 6),
                    Text(classic ? 'CLASSIC PLAY' : 'QUICK PLAY',
                        style: ZcText.heading(10.5)
                            .copyWith(letterSpacing: 0.8)),
                  ]),
                ),
                const SizedBox(height: 10),
                Text('Game Starts In', style: ZcText.heading(15)),
                const SizedBox(height: 6),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: ZcColors.neonPurple, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color:
                            ZcColors.neonPurple.withValues(alpha: 0.5),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 50,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('$_left',
                              key: const Key('countdownValue'),
                              style: ZcText.display(40,
                                  color: ZcColors.gold)),
                        ),
                      ),
                      Text('sec', style: ZcText.body(11)),
                    ],
                  ),
                ),
                const Spacer(),
                Text('Wait for other players...', style: ZcText.body(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Player tiles (compact): avatar ring + name + status + dashed invites.
  Widget _playerTiles(RoomLobby? lobby, String? myId) {
    final members = lobby?.members ?? const <RoomMember>[];
    final max = lobby?.maxPlayers ?? 4;
    final tiles = <Widget>[
      for (var i = 0; i < members.length; i++)
        Expanded(child: _memberTile(members[i], lobby, myId)),
      for (var i = members.length; i < max; i++)
        Expanded(child: _inviteTile()),
    ];
    final row = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) row.add(const SizedBox(width: 8));
      row.add(tiles[i]);
    }
    return Row(children: row);
  }

  Widget _memberTile(RoomMember m, RoomLobby? lobby, String? myId) {
    final isHost = m.userId == lobby?.hostId;
    final isMe = m.userId == myId;
    final avatar = kAvatarFor(m.userId);
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMe ? ZcColors.gold : const Color(0x2EFFFFFF),
            width: isMe ? 1.6 : 1.1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: m.ready
                          ? ZcColors.onlineGreen
                          : ZcColors.neonPurple,
                      width: 2.2),
                ),
                child: ClipOval(
                    child: Image.asset(avatar, fit: BoxFit.cover)),
              ),
              if (isHost)
                const Positioned(
                  right: -2,
                  top: -6,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Color(0xFF0D2C15),
                    child: Text('H',
                        style: TextStyle(
                            color: ZcColors.onlineGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
                )
              else
                Positioned(
                  right: -2,
                  top: -2,
                  child: CircleAvatar(
                    radius: 7,
                    backgroundColor: m.ready
                        ? ZcColors.onlineGreen
                        : const Color(0xFF2A165E),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(m.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZcText.body(11.5,
                    color: Colors.white, weight: FontWeight.w700)),
          ),
          const SizedBox(height: 3),
          if (isMe)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: ZcColors.neonPurple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('You',
                  style: ZcText.body(9,
                      color: Colors.white, weight: FontWeight.w800)),
            )
          else
            Text('Online',
                style: ZcText.body(9.5,
                    color: ZcColors.onlineGreen,
                    weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _inviteTile() => Container(
        height: 118,
        decoration: BoxDecoration(
          color: ZcColors.panelDeepBlue.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_alt_rounded,
                color: Colors.white38, size: 26),
            const SizedBox(height: 8),
            Text('Invite\nPlayer',
                textAlign: TextAlign.center,
                style: ZcText.body(10).copyWith(height: 1.25)),
          ],
        ),
      );

  /// Stats strip: Players / Cards / Game Time / Target Score.
  Widget _statsStrip(RoomLobby? lobby, bool classic) {
    Widget cell(IconData icon, Color color, String label, String value) =>
        Expanded(
          child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: ZcText.body(10)),
                    Text(value,
                        style: ZcText.body(11.5,
                            color: ZcColors.gold,
                            weight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ]),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      child: Row(children: [
        cell(Icons.groups_rounded, ZcColors.gemPurple, 'Players',
            '${lobby?.members.length ?? 1} / ${lobby?.maxPlayers ?? 4}'),
        cell(Icons.style_rounded, ZcColors.drawBlue, 'Cards',
            '${lobby?.handSize ?? 13}'),
        cell(Icons.schedule_rounded, ZcColors.onlineGreen, 'Game Time',
            classic ? '10 - 20 min' : '5 - 10 min'),
        cell(Icons.flag_rounded, ZcColors.gold, 'Target Score',
            '${lobby?.target ?? 200} Pts'),
      ]),
    );
  }

  /// Rules reminder: sequences not allowed + sample run crossed out.
  Widget _rulesStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: Color(0xFF2A165E),
          child: Icon(Icons.info_outline_rounded,
              color: ZcColors.gemPurple, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SEQUENCES ARE NOT ALLOWED',
                  style:
                      ZcText.heading(11.5).copyWith(letterSpacing: 0.5)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text:
                          'Remember: 3 or more cards with the same number = ',
                      style: ZcText.body(10)),
                  TextSpan(
                      text: 'ZERO',
                      style: ZcText.body(10,
                          color: ZcColors.gold, weight: FontWeight.w800)),
                ]),
              ),
            ],
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            const ZcCardFan(
              cards: [
                ('3', ZcSuit.clubs, 3),
                ('4', ZcSuit.spades, 4),
                ('5', ZcSuit.hearts, 5),
              ],
              cardWidth: 24,
              overlap: 0.5,
              fanAngle: 0.12,
            ),
            const Icon(Icons.block_rounded,
                color: ZcColors.errorRed, size: 40),
          ],
        ),
      ]),
    );
  }

  /// YOUR CARDS preview fan + SORT chip.
  Widget _yourCards(bool classic) {
    const preview = [
      ('2', ZcSuit.clubs, 2),
      ('5', ZcSuit.diamonds, 5),
      ('7', ZcSuit.spades, 7),
      ('9', ZcSuit.hearts, 9),
      ('J', ZcSuit.spades, 11),
      ('Q', ZcSuit.hearts, 12),
      ('K', ZcSuit.diamonds, 13),
      ('A', ZcSuit.clubs, 1),
      ('3', ZcSuit.diamonds, 3),
      ('6', ZcSuit.hearts, 6),
      ('8', ZcSuit.spades, 8),
      ('10', ZcSuit.clubs, 10),
      ('A', ZcSuit.hearts, 1),
    ];
    final cards =
        classic ? preview : preview.take(7).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('YOUR CARDS  ',
              style: ZcText.heading(12.5).copyWith(letterSpacing: 1)),
          Text('${cards.length} Cards',
              style: ZcText.body(11.5,
                  color: ZcColors.gold, weight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF2A165E),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: ZcColors.neonPurple.withValues(alpha: 0.5),
                  width: 1),
            ),
            child: Row(children: [
              Text('SORT',
                  style:
                      ZcText.heading(10.5).copyWith(letterSpacing: 0.8)),
              const SizedBox(width: 5),
              const Icon(Icons.swap_vert_rounded,
                  color: ZcColors.gemPurple, size: 14),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Center(
          child: ZcCardFan(
            cards: cards,
            cardWidth: 30,
            overlap: 0.82,
            fanAngle: 0.05,
          ),
        ),
      ],
    );
  }

  Widget _outlineAction({
    Key? key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4)),
            ),
          ],
        ),
      ),
    );
  }
}
