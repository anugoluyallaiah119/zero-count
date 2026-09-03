import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_button.dart';
import '../../ui/zc_header.dart';
import '../../ui/zc_theme.dart';
import 'recent_rooms.dart';
import 'room_repository.dart';

/// Join Room — pixel-matched to the Join_room mockup: green-door banner,
/// 6 neon code cells, gold JOIN ROOM, recent-rooms list (stored on-device)
/// and the "Don't have a room code?" create strip. Wired to
/// POST /api/rooms/:code/join (M1.6).
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _join([String? preset]) async {
    final code = (preset ?? _controller.text).trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-letter room code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final lobby = await ref.read(roomRepositoryProvider).join(code);
      final host = lobby.members
          .where((m) => m.userId == lobby.hostId)
          .firstOrNull;
      unawaited(ref.read(recentRoomsProvider.notifier).remember(RecentRoom(
            code: lobby.code,
            name: "${host?.displayName ?? 'Friend'}'s Room",
            host: host?.displayName ?? '',
            players: lobby.members.length,
            maxPlayers: lobby.maxPlayers,
          )));
      if (mounted) context.pushReplacement('/lobby/${lobby.code}');
    } on RoomException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentRoomsProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const ZcScreenHeader(
                title: 'JOIN ROOM',
                subtitle: 'Enter room code and join the fun!',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _JoinBanner(),
                      const SizedBox(height: 16),
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('ENTER ROOM CODE',
                                style: ZcText.heading(12.5)
                                    .copyWith(letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            _CodeCells(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: () => setState(() => _error = null),
                              onCompleted: () => _join(),
                            ),
                            const SizedBox(height: 10),
                            Text('Ask your friend for the 6-digit room code',
                                textAlign: TextAlign.center,
                                style: ZcText.body(11.5)),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: ZcText.body(12.5,
                                        color: ZcColors.errorRed)),
                              ),
                            const SizedBox(height: 14),
                            _busy
                                ? const SizedBox(
                                    height: 58,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                          color: ZcColors.gold),
                                    ),
                                  )
                                : ZcGoldButton(
                                    key: const Key('joinRoomConfirm'),
                                    label: 'JOIN ROOM',
                                    onPressed: _join,
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: Container(
                                height: 1, color: const Color(0x33FFFFFF))),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR',
                              style: ZcText.body(12,
                                  color: ZcColors.gemPurple,
                                  weight: FontWeight.w800)),
                        ),
                        Expanded(
                            child: Container(
                                height: 1, color: const Color(0x33FFFFFF))),
                      ]),
                      const SizedBox(height: 14),
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('RECENT ROOMS',
                                style: ZcText.heading(12.5)
                                    .copyWith(letterSpacing: 1.2)),
                            const SizedBox(height: 10),
                            if (recent.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                    'Rooms you create or join will show up here',
                                    textAlign: TextAlign.center,
                                    style: ZcText.body(12)),
                              )
                            else
                              for (var i = 0; i < recent.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                _RecentRoomTile(
                                  room: recent[i],
                                  accent: _accents[i % _accents.length],
                                  icon: _accentIcons[
                                      i % _accentIcons.length],
                                  busy: _busy,
                                  onJoin: () => _join(recent[i].code),
                                ),
                              ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _panel(
                        child: Row(children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0xFF2A165E),
                            child: Icon(Icons.lock_rounded,
                                color: ZcColors.textSecondary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text("Don't have a room code?",
                                    style: ZcText.heading(14)),
                                const SizedBox(height: 2),
                                Text(
                                    'Create your own room and invite friends.',
                                    style: ZcText.body(11)
                                        .copyWith(height: 1.3)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            key: const Key('joinToCreateButton'),
                            onTap: () =>
                                context.pushReplacement('/create-room'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF8B3DFF),
                                  Color(0xFF5B14C8),
                                ]),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Row(children: [
                                Text('CREATE ROOM',
                                    style: ZcText.heading(11)),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 15),
                              ]),
                            ),
                          ),
                        ]),
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

  static const _accents = [
    ZcColors.gemPurple,
    ZcColors.drawBlue,
    ZcColors.onlineGreen,
    ZcColors.gold,
  ];
  static const _accentIcons = [
    Icons.workspace_premium_rounded,
    Icons.star_rounded,
    Icons.diamond_rounded,
    Icons.emoji_events_rounded,
  ];

  Widget _panel({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ZcColors.panelDeepBlue.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
        ),
        child: child,
      );
}

/// Banner: JOIN A ROOM copy + bullets left, night street + green door right.
class _JoinBanner extends StatelessWidget {
  const _JoinBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 196,
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
              widthFactor: 0.55,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.0, 0.45],
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
              padding: const EdgeInsets.only(right: 14),
              child: Image.asset('assets/art/door_join.png', height: 132),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JOIN A ROOM',
                    style: ZcText.body(11,
                        color: ZcColors.onlineGreen, weight: FontWeight.w900)
                        .copyWith(letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text('Jump into the\ngame!',
                    style: ZcText.heading(21).copyWith(height: 1.1)),
                const SizedBox(height: 4),
                Text('Enter the room code shared\nby your friend to join instantly.',
                    style: ZcText.body(10.5).copyWith(height: 1.3)),
                const Spacer(),
                _bullet(Icons.groups_rounded, ZcColors.gemPurple,
                    'Play with your friends'),
                const SizedBox(height: 4),
                _bullet(Icons.bolt_rounded, ZcColors.drawBlue,
                    'Real-time fun'),
                const SizedBox(height: 4),
                _bullet(Icons.star_rounded, ZcColors.gold,
                    'Compete and win'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(IconData icon, Color color, String text) => Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 7),
        Text(text,
            style: ZcText.body(11.5,
                color: Colors.white, weight: FontWeight.w700)),
      ]);
}

/// Six neon code cells backed by one hidden text field (same pattern as the
/// OTP screen): first cell glows while empty, cells fill left to right.
class _CodeCells extends StatelessWidget {
  const _CodeCells({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Invisible input that owns the keyboard.
        Opacity(
          opacity: 0,
          child: TextField(
            key: const Key('roomCodeField'),
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp('[A-HJ-NP-Z2-9a-hj-np-z]')),
            ],
            onChanged: (_) {
              onChanged();
              if (controller.text.length == 6) onCompleted();
            },
          ),
        ),
        GestureDetector(
          onTap: () => focusNode.requestFocus(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++)
                _cell(
                  i < controller.text.length
                      ? controller.text[i].toUpperCase()
                      : '',
                  active: i == controller.text.length,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(String ch, {required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 58,
      decoration: BoxDecoration(
        color: ZcColors.panelInput.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? ZcColors.neonPurple : const Color(0x2EFFFFFF),
          width: active ? 1.8 : 1.1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: ZcColors.neonPurple.withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Center(
        child: ch.isEmpty
            ? (active
                ? Container(width: 2, height: 26, color: Colors.white70)
                : Container(
                    width: 12,
                    height: 2,
                    color: Colors.white24,
                  ))
            : Text(ch,
                style: ZcText.heading(22).copyWith(letterSpacing: 0)),
      ),
    );
  }
}

/// One recent-room row: accent icon, name/host, occupancy, JOIN button.
class _RecentRoomTile extends StatelessWidget {
  const _RecentRoomTile({
    required this.room,
    required this.accent,
    required this.icon,
    required this.busy,
    required this.onJoin,
  });

  final RecentRoom room;
  final Color accent;
  final IconData icon;
  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: accent.withValues(alpha: 0.16),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZcText.heading(13.5)),
              Text('Hosted by ${room.host}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZcText.body(11, color: accent)),
            ],
          ),
        ),
        Icon(Icons.groups_rounded, color: accent, size: 15),
        const SizedBox(width: 4),
        Text('${room.players} / ${room.maxPlayers}',
            style: ZcText.body(12,
                color: Colors.white, weight: FontWeight.w700)),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: busy ? null : onJoin,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF2A165E),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: ZcColors.neonPurple.withValues(alpha: 0.6),
                  width: 1.1),
            ),
            child: Text('JOIN',
                style: ZcText.heading(11.5).copyWith(letterSpacing: 0.8)),
          ),
        ),
      ]),
    );
  }
}
