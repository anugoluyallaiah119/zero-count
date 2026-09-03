import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_button.dart';
import '../../ui/zc_header.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import '../player/profile_repository.dart';

/// One friend entry in the invite list (locally remembered — the server
/// referral API ships with the social update).
class InviteFriend {
  const InviteFriend({
    required this.name,
    required this.status,
    required this.detail,
    required this.avatarIndex,
  });

  final String name;

  /// 'joined' or 'pending'.
  final String status;
  final String detail;
  final int avatarIndex;
}

/// Local invite stats — counts invites sent from this device until the
/// referral API lands.
class InviteStats {
  const InviteStats(
      {required this.invited, required this.joined, required this.points});

  final int invited;
  final int joined;
  final int points;
}

final inviteStatsProvider =
    StateProvider<InviteStats>((ref) => const InviteStats(invited: 0, joined: 0, points: 0));

final inviteFriendsProvider =
    StateProvider<List<InviteFriend>>((ref) => const []);

/// Invite Friends — pixel-matched to the Invite_friends mockup: gift hero
/// banner with reward bullets, share-link field + COPY, social share tiles,
/// invite stats, friends list and BACK TO HOME.
class InviteFriendsScreen extends ConsumerWidget {
  const InviteFriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inviteStatsProvider);
    final friends = ref.watch(inviteFriendsProvider);
    final name = ref.watch(profileProvider).valueOrNull?.name ?? 'Player';
    final link = 'https://zerocount.app/invite/$name';

    void soon(String what) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$what arrives with the social update'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ZcColors.panelPurple,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const ZcScreenHeader(
                title: 'INVITE FRIENDS',
                subtitle: 'Share the fun and earn rewards together!',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heroBanner(),
                      const SizedBox(height: 16),
                      _panel(Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('SHARE YOUR INVITE LINK'),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                decoration: BoxDecoration(
                                  color: ZcColors.panelInput,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                      color: const Color(0x33FFFFFF),
                                      width: 1),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.link_rounded,
                                      color: ZcColors.gemPurple, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(link,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ZcText.body(12,
                                            color: Colors.white)),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              key: const Key('copyInviteLink'),
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: link));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Invite link copied')));
                              },
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFF8B3DFF),
                                    Color(0xFF5B14C8),
                                  ]),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.copy_rounded,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text('COPY', style: ZcText.heading(12)),
                                ]),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 14),
                          Row(children: [
                            _shareTile(Icons.chat_rounded, 'WhatsApp',
                                const Color(0xFF1DA851),
                                () => soon('WhatsApp share')),
                            const SizedBox(width: 8),
                            _shareTile(Icons.facebook_rounded, 'Facebook',
                                const Color(0xFF1877F2),
                                () => soon('Facebook share')),
                            const SizedBox(width: 8),
                            _shareTile(Icons.send_rounded, 'Messenger',
                                const Color(0xFF9B30FF),
                                () => soon('Messenger share')),
                            const SizedBox(width: 8),
                            _shareTile(Icons.more_horiz_rounded, 'More',
                                const Color(0xFF3A3A4A),
                                () => soon('More share options')),
                          ]),
                        ],
                      )),
                      const SizedBox(height: 16),
                      _panel(Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('YOUR INVITE STATS'),
                          const SizedBox(height: 10),
                          Row(children: [
                            _statTile(Icons.groups_rounded, '${stats.invited}',
                                'Friends Invited'),
                            const SizedBox(width: 8),
                            _statTile(Icons.card_giftcard_rounded,
                                '${stats.joined}', 'Friends Joined'),
                            const SizedBox(width: 8),
                            _statTile(Icons.star_rounded,
                                '${stats.points}', 'Points Earned'),
                          ]),
                        ],
                      )),
                      const SizedBox(height: 16),
                      _panel(Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('FRIENDS LIST'),
                          const SizedBox(height: 6),
                          if (friends.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                  'Friends you invite will appear here',
                                  textAlign: TextAlign.center,
                                  style: ZcText.body(12)),
                            )
                          else
                            for (var i = 0; i < friends.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _friendTile(friends[i]),
                            ],
                        ],
                      )),
                      const SizedBox(height: 16),
                      ZcGoldButton(
                        key: const Key('inviteBackToHome'),
                        label: 'BACK TO HOME',
                        onPressed: () => context.go('/home'),
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

  /// Hero: reward bullets left, gift art right on purple glow.
  Widget _heroBanner() {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2A0A5E), Color(0xFF4A11B8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: ZcColors.neonPurple.withValues(alpha: 0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
              color: ZcColors.neonPurple.withValues(alpha: 0.3),
              blurRadius: 18),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 0, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite your friends',
                    style: ZcText.heading(18)),
                Text('Earn awesome rewards!', style: ZcText.body(11.5)),
                const Spacer(),
                _reward('assets/art/coin.png', 'You get ', '200', ' points'),
                const SizedBox(height: 6),
                _reward('assets/art/gem.png', 'Your friend gets ', '100',
                    ' points'),
                const SizedBox(height: 6),
                _reward('assets/art/gift_box.png',
                    'Earn more as your friends play!', null, null),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 9,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child:
                  Image.asset('assets/art/gift_box.png', height: 150),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _reward(String asset, String pre, String? gold, String? post) {
    return Row(children: [
      Image.asset(asset, width: 18, height: 18),
      const SizedBox(width: 8),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: pre,
                  style: ZcText.body(11.5, color: Colors.white)),
              if (gold != null)
                TextSpan(
                    text: gold,
                    style: ZcText.body(12,
                        color: ZcColors.gold, weight: FontWeight.w900)),
              if (post != null)
                TextSpan(
                    text: post,
                    style: ZcText.body(11.5, color: Colors.white)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _shareTile(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: ZcColors.panelInput,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0x2EFFFFFF), width: 1),
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: ZcText.body(10,
                        color: Colors.white, weight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );

  Widget _statTile(IconData icon, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: ZcColors.panelInput,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x2EFFFFFF), width: 1),
          ),
          child: Row(children: [
            Icon(icon, color: ZcColors.gemPurple, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: ZcText.heading(16)),
                    Text(label, style: ZcText.body(9)),
                  ],
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _friendTile(InviteFriend f) {
    final joined = f.status == 'joined';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZcColors.panelInput.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: joined ? ZcColors.onlineGreen : ZcColors.gemPurple,
                width: 2),
          ),
          child: ClipOval(
            child: Image.asset(
                kAvatars[f.avatarIndex % kAvatars.length].asset,
                fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZcText.heading(13.5)),
              Text(f.detail, style: ZcText.body(10.5)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A165E),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: joined
                    ? ZcColors.onlineGreen.withValues(alpha: 0.6)
                    : const Color(0x33FFFFFF),
                width: 1),
          ),
          child: Text(joined ? 'Joined' : 'Pending',
              style: ZcText.body(10,
                  color: joined ? ZcColors.onlineGreen : Colors.white70,
                  weight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Text(joined ? '+100 pts' : '-',
            style: ZcText.body(11.5,
                color: joined ? ZcColors.gold : Colors.white38,
                weight: FontWeight.w800)),
      ]),
    );
  }

  Widget _label(String text) =>
      Text(text, style: ZcText.heading(12.5).copyWith(letterSpacing: 1.2));

  Widget _panel(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ZcColors.panelDeepBlue.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
        ),
        child: child,
      );
}
