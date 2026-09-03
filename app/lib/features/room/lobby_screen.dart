import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_button.dart' hide ZcCurrencyPill;
import '../../ui/zc_header.dart';
import '../../ui/zc_playing_card.dart';
import '../../ui/zc_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/avatar_catalog.dart';
import '../player/profile_repository.dart';
import 'room_repository.dart';

/// Lobby state for one room code, polled every 2s (M1.6). Live match
/// traffic moves to WebSocket in M1.7; polling a lobby is cheap and robust.
class LobbyController extends Notifier<RoomLobby?> {
  Timer? _poller;
  String _code = '';

  @override
  RoomLobby? build() {
    ref.onDispose(() => _poller?.cancel());
    return null;
  }

  void watch(String code) {
    _code = code;
    _poller?.cancel();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      state = await ref.read(roomRepositoryProvider).get(_code);
    } on RoomException {
      // Keep the last good lobby on transient errors.
    }
  }

  Future<void> setReady(bool ready) async {
    state = await ref.read(roomRepositoryProvider).setReady(_code, ready);
  }

  Future<void> leave() async {
    _poller?.cancel();
    try {
      await ref.read(roomRepositoryProvider).leave(_code);
    } on RoomException {
      // Leaving a vanished room is success as far as the UI cares.
    }
    state = null;
  }
}

final lobbyProvider =
    NotifierProvider<LobbyController, RoomLobby?>(LobbyController.new);

/// Room lobby — pixel-matched to the Play_inside_room mockup: header with
/// room name + copyable code, carnival banner with mode chip and stats,
/// player tiles with host crown + ready state, room settings, invite panel
/// and the READY TO START? card with gold START GAME (host) or READY toggle
/// (guest). Polls the room REST contract (M1.6).
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(lobbyProvider.notifier).watch(widget.code));
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(lobbyProvider);
    final myId = ref.watch(authControllerProvider).userId;
    return PopScope(
      onPopInvokedWithResult: (_, __) =>
          ref.read(lobbyProvider.notifier).leave(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
          child: SafeArea(
            child: lobby == null
                ? const Center(
                    child:
                        CircularProgressIndicator(color: ZcColors.gold))
                : _buildLobby(context, lobby, myId),
          ),
        ),
      ),
    );
  }

  Widget _buildLobby(BuildContext context, RoomLobby lobby, String? myId) {
    final isHost = lobby.isHost(myId ?? '');
    final me =
        lobby.members.where((m) => m.userId == myId).firstOrNull;
    final host = lobby.members
        .where((m) => m.userId == lobby.hostId)
        .firstOrNull;
    final roomName = "${host?.displayName ?? 'Friend'}'s Room";
    return Column(
      children: [
        _LobbyHeader(code: lobby.code, roomName: roomName),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LobbyBanner(lobby: lobby),
                const SizedBox(height: 16),
                Row(children: [
                  Text('PLAYERS ',
                      style:
                          ZcText.heading(12.5).copyWith(letterSpacing: 1.2)),
                  Text('( ${lobby.members.length} / ${lobby.maxPlayers} )',
                      style: ZcText.body(12.5,
                          color: ZcColors.onlineGreen,
                          weight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                _PlayerGrid(lobby: lobby, myId: myId),
                const SizedBox(height: 16),
                Text('ROOM SETTINGS',
                    style:
                        ZcText.heading(12.5).copyWith(letterSpacing: 1.2)),
                const SizedBox(height: 10),
                _SettingsPanel(lobby: lobby, isHost: isHost),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _InvitePanel(code: lobby.code)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StartPanel(
                        lobby: lobby,
                        isHost: isHost,
                        ready: me?.ready ?? false,
                        onReady: () => ref
                            .read(lobbyProvider.notifier)
                            .setReady(!(me?.ready ?? false)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 14, color: ZcColors.gemPurple),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isHost
                            ? 'Only the host can start the game and change settings.'
                            : 'Waiting for the host to start the game.',
                        style: ZcText.body(11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Header: back, room name + pencil, copyable room code, pills, bell, gear.
class _LobbyHeader extends ConsumerWidget {
  const _LobbyHeader({required this.code, required this.roomName});

  final String code;
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).valueOrNull;
    return Padding(
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
                  child: Text(roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ZcText.heading(16)),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.edit_rounded,
                    color: ZcColors.gemPurple, size: 14),
              ]),
              GestureDetector(
                key: const Key('roomCode'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Room code copied')));
                },
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    Text('Room Code: ', style: ZcText.body(11.5)),
                    Text(code,
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
                asset: 'assets/art/coin.png', value: '${p?.coins ?? 0}'),
            const SizedBox(width: 6),
            ZcCurrencyPill(
                asset: 'assets/art/gem.png', value: '${p?.gems ?? 0}'),
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
    );
  }
}

/// Banner: mode chip, "Room is Ready!", stats, carnival art + mask.
class _LobbyBanner extends StatelessWidget {
  const _LobbyBanner({required this.lobby});

  final RoomLobby lobby;

  @override
  Widget build(BuildContext context) {
    final classic = lobby.handSize == 13;
    return Container(
      height: 236,
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
              widthFactor: 0.58,
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
              padding: const EdgeInsets.only(right: 16),
              child: Image.asset('assets/art/mask_carnival.png',
                  height: 140),
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
                    border: Border.all(
                        color: const Color(0x40FFFFFF), width: 1),
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
                const SizedBox(height: 8),
                Text('Room is Ready!', style: ZcText.heading(22)),
                Text('Invite your friends and\nlet the game begin.',
                    style: ZcText.body(11.5).copyWith(height: 1.35)),
                const Spacer(),
                _stat(Icons.groups_rounded, ZcColors.gemPurple, 'Players',
                    '${lobby.members.length} / ${lobby.maxPlayers}',
                    valueColor: ZcColors.onlineGreen),
                const SizedBox(height: 5),
                _stat(Icons.style_rounded, ZcColors.drawBlue, 'Cards',
                    '${lobby.handSize}',
                    valueColor: ZcColors.gold),
                const SizedBox(height: 5),
                _stat(Icons.schedule_rounded, ZcColors.gemPurple,
                    'Game Time', classic ? '10 - 20 min' : '5 - 10 min',
                    valueColor: ZcColors.gold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String label, String value,
          {required Color valueColor}) =>
      Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        SizedBox(
            width: 78,
            child: Text(label,
                style: ZcText.body(12,
                    color: Colors.white, weight: FontWeight.w600))),
        Text(value,
            style: ZcText.body(12.5,
                color: valueColor, weight: FontWeight.w800)),
      ]);
}

/// Player tiles: host crown + badge, online/ready dot, dashed invite slots.
class _PlayerGrid extends StatelessWidget {
  const _PlayerGrid({required this.lobby, required this.myId});

  final RoomLobby lobby;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (var i = 0; i < lobby.members.length; i++) {
      final m = lobby.members[i];
      tiles.add(Expanded(child: _memberTile(m, i)));
    }
    for (var i = lobby.members.length; i < lobby.maxPlayers; i++) {
      tiles.add(Expanded(child: _inviteTile(context)));
    }
    final row = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) row.add(const SizedBox(width: 8));
      row.add(tiles[i]);
    }
    return Row(children: row);
  }

  Widget _memberTile(RoomMember m, int index) {
    final isHost = m.userId == lobby.hostId;
    final isMe = m.userId == myId;
    // Members carry no avatar id in the room contract — pick a stable art
    // avatar per user id so tiles stay consistent across polls.
    final avatar =
        kAvatars[m.userId.hashCode.abs() % kAvatars.length].asset;
    return Container(
      height: 152,
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
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: m.ready
                          ? ZcColors.onlineGreen
                          : ZcColors.neonPurple,
                      width: 2.4),
                ),
                child:
                    ClipOval(child: Image.asset(avatar, fit: BoxFit.cover)),
              ),
              if (isHost)
                const Positioned(
                  left: -4,
                  top: -10,
                  child: Icon(Icons.workspace_premium_rounded,
                      color: ZcColors.gold, size: 20),
                ),
              Positioned(
                right: -2,
                top: -2,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: m.ready
                      ? ZcColors.onlineGreen
                      : const Color(0xFF2A165E),
                  child: m.ready
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12)
                      : const Icon(Icons.hourglass_top_rounded,
                          color: Colors.white54, size: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(m.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ZcText.body(13,
                  color: Colors.white, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (isHost)
            _badge('HOST', ZcColors.onlineGreen)
          else if (isMe)
            _badge('You', ZcColors.neonPurple)
          else
            Text(m.ready ? 'Ready' : 'Online',
                style: ZcText.body(10.5,
                    color: m.ready
                        ? ZcColors.onlineGreen
                        : ZcColors.onlineGreen,
                    weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: color == ZcColors.onlineGreen
              ? const Color(0xFF0D2C15)
              : ZcColors.neonPurple,
          borderRadius: BorderRadius.circular(9),
          border: color == ZcColors.onlineGreen
              ? Border.all(color: ZcColors.onlineGreen, width: 1)
              : null,
        ),
        child: Text(text,
            style: ZcText.body(10.5,
                color: Colors.white, weight: FontWeight.w800)),
      );

  Widget _inviteTile(BuildContext context) => GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: lobby.code));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Room code copied — send it to a friend!')));
        },
        child: Container(
          height: 152,
          decoration: BoxDecoration(
            color: ZcColors.panelDeepBlue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      color: Colors.white38, size: 38),
                  const Positioned(
                    right: -4,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Color(0xFF2A165E),
                      child: Icon(Icons.add_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Invite\nPlayer',
                  textAlign: TextAlign.center,
                  style: ZcText.body(11.5).copyWith(height: 1.3)),
            ],
          ),
        ),
      );
}

/// Room settings panel: values from the lobby; editing ships with the
/// backend room-update endpoint (post-V2), so steppers explain on tap.
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.lobby, required this.isHost});

  final RoomLobby lobby;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    void locked() {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isHost
            ? 'Room settings editing arrives with the room-update API'
            : 'Only the host can change settings'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ZcColors.panelPurple,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }

    Widget row(IconData icon, Color color, String title, String subtitle,
            Widget trailing) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ZcText.heading(13)),
                  Text(subtitle, style: ZcText.body(10.5)),
                ],
              ),
            ),
            trailing,
          ]),
        );

    Widget stepper(String value) => Row(children: [
          _step(Icons.remove_rounded, locked),
          SizedBox(
            width: 58,
            child: Text(value,
                textAlign: TextAlign.center,
                style: ZcText.heading(16)
                    .copyWith(color: ZcColors.gold)),
          ),
          _step(Icons.add_rounded, locked),
        ]);

    return Container(
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      child: Column(children: [
        row(Icons.flag_rounded, ZcColors.gemPurple, 'Target Score',
            'Lowest score wins', stepper('${lobby.target}')),
        row(Icons.schedule_rounded, ZcColors.onlineGreen, 'Turn Time',
            'Time per turn', stepper('20 sec')),
        row(
          Icons.style_rounded,
          ZcColors.gold,
          'Wild Cards',
          'Use wild cards in game',
          Switch(
            value: true,
            onChanged: (_) => locked(),
            activeTrackColor: ZcColors.takeGreen,
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF2A165E),
          ),
        ),
        row(
          Icons.shield_rounded,
          ZcColors.drawBlue,
          'Room Privacy',
          'Friends can join',
          GestureDetector(
            onTap: locked,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A165E),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(children: [
                Text('Friends Only', style: ZcText.body(11.5,
                    color: Colors.white, weight: FontWeight.w700)),
                const SizedBox(width: 5),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 16),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _step(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2A165E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      );
}

/// Invite panel: WhatsApp / Facebook / Copy Code / More round buttons.
class _InvitePanel extends StatelessWidget {
  const _InvitePanel({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    void soon(String what) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$what arrives with the social update'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ZcColors.panelPurple,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }

    Widget round(IconData icon, String label, Color color,
            VoidCallback onTap, {Key? key}) =>
        GestureDetector(
          key: key,
          onTap: onTap,
          child: SizedBox(
            width: 38,
            child: Column(children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 15),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: ZcText.body(9.5,
                        color: Colors.white, weight: FontWeight.w600)),
              ),
            ]),
          ),
        );

    return Container(
      height: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.share_rounded,
                color: ZcColors.gemPurple, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('INVITE FRIENDS',
                    style:
                        ZcText.heading(11.5).copyWith(letterSpacing: 0.8)),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Share room code or invite\nfriends to join the fun!',
              style: ZcText.body(10.5).copyWith(height: 1.35)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              round(Icons.chat_rounded, 'WhatsApp',
                  const Color(0xFF1DA851), () => soon('WhatsApp invite')),
              round(Icons.facebook_rounded, 'Facebook',
                  const Color(0xFF1877F2), () => soon('Facebook invite')),
              round(Icons.copy_rounded, 'Copy Code',
                  const Color(0xFF7B2FF7), () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Room code copied')));
              }, key: const Key('copyCodeButton')),
              round(Icons.more_horiz_rounded, 'More',
                  const Color(0xFF3A3A4A), () => soon('Share invite')),
            ],
          ),
        ],
      ),
    );
  }
}

/// READY TO START? card: mini card fan + START GAME (host) / READY toggle.
class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.lobby,
    required this.isHost,
    required this.ready,
    required this.onReady,
  });

  final RoomLobby lobby;
  final bool isHost;
  final bool ready;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZcColors.panelPurple.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text('READY TO\nSTART?',
                  style: ZcText.heading(13).copyWith(height: 1.15)),
            ),
            const ZcCardFan(
              cards: [
                ('J', ZcSuit.spades, 11),
                ('Q', ZcSuit.hearts, 12),
                ('K', ZcSuit.diamonds, 13),
              ],
              cardWidth: 30,
              overlap: 0.42,
              fanAngle: 0.22,
            ),
          ]),
          Text('All set? Start the game and\nlet the challenge begin!',
              style: ZcText.body(10).copyWith(height: 1.35)),
          const Spacer(),
          if (isHost)
            ZcGoldButton(
              key: const Key('startMatchButton'),
              label: lobby.startable ? 'START GAME' : 'WAITING…',
              height: 46,
              fontSize: 13,
              onPressed: lobby.startable
                  ? () => context.push('/countdown/${lobby.code}')
                  : null,
            )
          else
            ZcGoldButton(
              key: const Key('readyButton'),
              label: ready ? 'NOT READY' : "I'M READY",
              height: 46,
              fontSize: 13,
              onPressed: onReady,
            ),
        ],
      ),
    );
  }
}

