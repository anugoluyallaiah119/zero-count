import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_button.dart';
import '../../ui/zc_header.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import '../player/profile_repository.dart';
import 'recent_rooms.dart';
import 'room_repository.dart';

/// Create Room — pixel-matched to the Create_room mockup: carnival banner
/// with game-mode summary, room-name field, player slots (you + invites),
/// game settings steppers/toggle, invite-friends buttons and gold
/// CREATE ROOM. Wired to POST /api/rooms (M1.6).
///
/// Turn time and wild cards are UI-ahead-of-backend: they are collected here
/// and travel in the lobby state once the API accepts them (post-V2 scope).
class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key, this.classic = false});

  /// Game mode the room is created for (7-card quick vs 13-card classic).
  final bool classic;

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  late final TextEditingController _nameController;
  late int _target;
  int _turnTime = 20;
  bool _wildCards = true;
  bool _busy = false;
  String? _error;

  bool get _classic => widget.classic;

  @override
  void initState() {
    super.initState();
    _target = _classic ? 200 : 100;
    final name = ref.read(profileProvider).valueOrNull?.name ?? 'My';
    _nameController = TextEditingController(text: "$name's Room");
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final lobby = await ref.read(roomRepositoryProvider).create(
            maxPlayers: 4,
            handSize: _classic ? 13 : 7,
            target: _target,
          );
      unawaited(ref.read(recentRoomsProvider.notifier).remember(RecentRoom(
            code: lobby.code,
            name: _nameController.text.trim(),
            host: 'You',
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const ZcScreenHeader(
                title: 'CREATE ROOM',
                subtitle: 'Set up your game and invite friends!',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ModeBanner(classic: _classic),
                      const SizedBox(height: 16),
                      _sectionLabel('ROOM NAME'),
                      _RoomNameField(controller: _nameController),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('SELECT PLAYERS', padded: false),
                          Text('1 / 4 Players',
                              style: ZcText.body(12,
                                  color: ZcColors.onlineGreen,
                                  weight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _PlayerSlots(),
                      const SizedBox(height: 16),
                      _sectionLabel('GAME SETTINGS'),
                      _SettingStepper(
                        icon: Icons.flag_rounded,
                        iconColor: ZcColors.gemPurple,
                        title: 'TARGET SCORE',
                        subtitle: 'Lowest score wins',
                        value: '$_target',
                        onMinus: () => setState(() =>
                            _target = (_target - 50).clamp(50, 1000)),
                        onPlus: () => setState(
                            () => _target = (_target + 50).clamp(50, 1000)),
                      ),
                      const SizedBox(height: 10),
                      _SettingStepper(
                        icon: Icons.schedule_rounded,
                        iconColor: ZcColors.onlineGreen,
                        title: 'TURN TIME',
                        subtitle: 'Time per turn',
                        value: '$_turnTime sec',
                        onMinus: () => setState(() =>
                            _turnTime = (_turnTime - 5).clamp(10, 60)),
                        onPlus: () => setState(
                            () => _turnTime = (_turnTime + 5).clamp(10, 60)),
                      ),
                      const SizedBox(height: 10),
                      _SettingToggle(
                        icon: Icons.style_rounded,
                        iconColor: ZcColors.gold,
                        title: 'WILD CARDS',
                        subtitle: 'Use wild cards in game',
                        value: _wildCards,
                        onChanged: (v) => setState(() => _wildCards = v),
                      ),
                      const SizedBox(height: 16),
                      _sectionLabel('INVITE FRIENDS'),
                      Row(children: [
                        _InviteButton(
                            icon: Icons.link_rounded,
                            label: 'COPY LINK',
                            color: const Color(0xFF7B2FF7),
                            onTap: _copyLink),
                        const SizedBox(width: 8),
                        _InviteButton(
                            icon: Icons.chat_rounded,
                            label: 'WHATSAPP',
                            color: const Color(0xFF1DA851),
                            onTap: () => _soon('WhatsApp invite')),
                        const SizedBox(width: 8),
                        _InviteButton(
                            icon: Icons.facebook_rounded,
                            label: 'FACEBOOK',
                            color: const Color(0xFF1877F2),
                            onTap: () => _soon('Facebook invite')),
                        const SizedBox(width: 8),
                        _InviteButton(
                            icon: Icons.share_rounded,
                            label: 'MORE',
                            color: const Color(0xFF3A3A4A),
                            onTap: () => _soon('Share invite')),
                      ]),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: ZcText.body(13,
                                  color: ZcColors.errorRed)),
                        ),
                      const SizedBox(height: 16),
                      _busy
                          ? const SizedBox(
                              height: 58,
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: ZcColors.gold),
                              ),
                            )
                          : ZcGoldButton(
                              key: const Key('createRoomConfirm'),
                              label: 'CREATE ROOM',
                              onPressed: _create,
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

  void _copyLink() {
    Clipboard.setData(const ClipboardData(
        text: 'https://zerocount.app/invite')); // deep link lands post-V2
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Invite link copied — share it with friends!'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZcColors.panelPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$what arrives with the social update'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZcColors.panelPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _sectionLabel(String text, {bool padded = true}) => Padding(
        padding: EdgeInsets.only(bottom: padded ? 10 : 0),
        child: Text(text,
            style: ZcText.heading(12.5).copyWith(letterSpacing: 1.2)),
      );
}

/// Top banner: mode summary left, carnival art + mask right.
class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.classic});

  final bool classic;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: ZcColors.panelDeepBlue.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Carnival street art fills the right half; mask sits on it.
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
              padding: const EdgeInsets.only(right: 18),
              child: Image.asset('assets/art/mask_carnival.png', height: 130),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF2A165E),
                    child: Icon(Icons.groups_rounded,
                        color: ZcColors.gemPurple, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text('You are creating a', style: ZcText.body(12)),
                ]),
                const SizedBox(height: 4),
                Text(classic ? 'CLASSIC PLAY' : 'QUICK PLAY',
                    style: ZcText.heading(24).copyWith(letterSpacing: 1)),
                Text('room for your friends.', style: ZcText.body(12)),
                const Spacer(),
                _bannerStat(Icons.style_rounded, ZcColors.drawBlue,
                    '${classic ? 13 : 7} cards'),
                const SizedBox(height: 6),
                _bannerStat(Icons.schedule_rounded, ZcColors.gemPurple,
                    classic ? '10 - 20 min' : '5 - 10 min'),
                const SizedBox(height: 6),
                _bannerStat(
                    Icons.groups_rounded, ZcColors.onlineGreen, '2 - 4 Players'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerStat(IconData icon, Color color, String text) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: ZcText.body(12.5,
                  color: Colors.white, weight: FontWeight.w700)),
        ],
      );
}

/// Room name input: star tile + text + pencil.
class _RoomNameField extends StatelessWidget {
  const _RoomNameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ZcColors.panelInput,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x40FFFFFF), width: 1.2),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: ZcColors.neonPink,
            borderRadius: BorderRadius.circular(9),
          ),
          child:
              const Icon(Icons.star_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: const Key('roomNameField'),
            controller: controller,
            maxLength: 24,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              isDense: true,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 14),
          child:
              Icon(Icons.edit_rounded, color: ZcColors.gemPurple, size: 18),
        ),
      ]),
    );
  }
}

/// 4 player slots: you (profile avatar) + three dashed invite slots.
class _PlayerSlots extends ConsumerWidget {
  const _PlayerSlots();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).valueOrNull;
    return Row(children: [
      Expanded(
        child: _slot(
          child: Column(children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: ZcColors.onlineGreen, width: 2.4),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                        avatarAsset(p?.avatar ?? 'hoodie'),
                        fit: BoxFit.cover),
                  ),
                ),
                const Positioned(
                  right: -2,
                  top: -2,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: ZcColors.onlineGreen,
                    child: Icon(Icons.check_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(p?.name ?? 'You',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZcText.body(13,
                    color: Colors.white, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: ZcColors.neonPurple,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('You',
                  style: ZcText.body(10.5,
                      color: Colors.white, weight: FontWeight.w800)),
            ),
          ]),
        ),
      ),
      for (var i = 0; i < 3; i++) ...[
        const SizedBox(width: 8),
        Expanded(child: _inviteSlot(context)),
      ],
    ]);
  }

  Widget _slot({required Widget child}) => Container(
        height: 148,
        decoration: BoxDecoration(
          color: ZcColors.panelPurple.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
        ),
        child: Center(child: child),
      );

  Widget _inviteSlot(BuildContext context) => GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Friend invites arrive with the social update — share the room code for now'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ZcColors.panelPurple,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )),
        child: Container(
          height: 148,
          decoration: BoxDecoration(
            color: ZcColors.panelDeepBlue.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        color: Colors.white38, size: 40),
                    const Positioned(
                      right: -2,
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
                    style: ZcText.body(12).copyWith(height: 1.3)),
              ],
            ),
          ),
        ),
      );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x40FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Settings row with − value + stepper.
class _SettingStepper extends StatelessWidget {
  const _SettingStepper({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return _settingShell(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: Row(children: [
        _stepButton(Icons.remove_rounded, onMinus),
        SizedBox(
          width: 64,
          child: Text(value,
              textAlign: TextAlign.center,
              style: ZcText.heading(17).copyWith(color: ZcColors.gold)),
        ),
        _stepButton(Icons.add_rounded, onPlus),
      ]),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF2A165E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

/// Settings row with a green toggle.
class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _settingShell(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        key: const Key('wildCardsToggle'),
        value: value,
        onChanged: onChanged,
        activeTrackColor: ZcColors.takeGreen,
        activeThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFF2A165E),
        inactiveThumbColor: Colors.white70,
      ),
    );
  }
}

Widget _settingShell({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required Widget trailing,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: ZcColors.panelPurple.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
    ),
    child: Row(children: [
      CircleAvatar(
        radius: 19,
        backgroundColor: iconColor.withValues(alpha: 0.18),
        child: Icon(icon, color: iconColor, size: 19),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title,
                  style: ZcText.heading(12.5).copyWith(letterSpacing: 0.6)),
              const SizedBox(width: 5),
              const Icon(Icons.info_outline_rounded,
                  color: ZcColors.textSecondary, size: 13),
            ]),
            Text(subtitle, style: ZcText.body(11)),
          ],
        ),
      ),
      trailing,
    ]),
  );
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4)),
          ]),
        ),
      ),
    );
  }
}
