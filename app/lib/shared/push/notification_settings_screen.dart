import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_theme.dart';
import 'push_notification_service.dart';

/// Notification preferences screen. Lets the user mute/unmute each kind.
/// Accessed from the Leaderboard header or Settings entry (future).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends ConsumerState<NotificationSettingsScreen> {
  Set<ZcNotifKind>? _muted;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await ref.read(pushNotificationServiceProvider).mutes();
      if (mounted) setState(() => _muted = m);
    } catch (_) {
      if (mounted) setState(() => _muted = {});
    }
  }

  Future<void> _toggle(ZcNotifKind kind, bool currentlyMuted) async {
    if (_saving) return;
    setState(() => _saving = true);
    final svc = ref.read(pushNotificationServiceProvider);
    try {
      if (currentlyMuted) {
        await svc.unmuteKind(kind);
        setState(() => _muted!.remove(kind));
      } else {
        await svc.muteKind(kind);
        setState(() => _muted!.add(kind));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ZcColors.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF09031E), Color(0xFF140733)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.canPop() ? context.pop() : null,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0x33FFFFFF), width: 1.1),
                ),
                child: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'NOTIFICATIONS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (_saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ZcColors.neonPurple,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_muted == null) {
      return const Center(
        child: CircularProgressIndicator(color: ZcColors.neonPurple),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      children: [
        _sectionLabel('Match'),
        _row(ZcNotifKind.rematchNudge),
        _row(ZcNotifKind.matchResult),
        const SizedBox(height: 12),
        _sectionLabel('Engagement'),
        _row(ZcNotifKind.challengeNudge),
        _row(ZcNotifKind.streakAtRisk),
        _row(ZcNotifKind.rewardGranted),
        const SizedBox(height: 12),
        _sectionLabel('Social'),
        _row(ZcNotifKind.friendRequest),
        const SizedBox(height: 12),
        _sectionLabel('Events'),
        _row(ZcNotifKind.contestStarting),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: const Text(
            'Muted alerts are never sent to your device. '
            'We keep these to 1 push per day during waking hours.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _row(ZcNotifKind kind) {
    final isMuted = _muted!.contains(kind);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isMuted)
                  const Text(
                    'Muted',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: !isMuted,
            onChanged: (_) => _toggle(kind, isMuted),
            activeColor: ZcColors.neonPurple,
            activeTrackColor: ZcColors.neonPurple.withValues(alpha: 0.3),
            inactiveTrackColor: const Color(0x22FFFFFF),
            inactiveThumbColor: Colors.white38,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// IN-APP BANNER OVERLAY
// =============================================================================

/// Wrap around a subtree to show foreground FCM messages as toast banners.
class ZcNotifBannerOverlay extends ConsumerStatefulWidget {
  const ZcNotifBannerOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ZcNotifBannerOverlay> createState() =>
      _ZcNotifBannerOverlayState();
}

class _ZcNotifBannerOverlayState
    extends ConsumerState<ZcNotifBannerOverlay> {
  ZcNotifBanner? _current;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushNotificationServiceProvider);
    push.banners.listen((banner) {
      if (!mounted) return;
      setState(() => _current = banner);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _current == banner) {
          setState(() => _current = null);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: _BannerCard(
              banner: _current!,
              onDismiss: () => setState(() => _current = null),
            ),
          ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onDismiss});
  final ZcNotifBanner banner;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A0E5C), Color(0xFF140632)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: ZcColors.neonPurple.withValues(alpha: 0.6), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_rounded,
                color: ZcColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (banner.body.isNotEmpty)
                    Text(
                      banner.body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white38, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ],
        ),
      ),
    );
  }
}
