import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_cosmetics.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import 'contest_repository.dart';

/// Tournament hub — lists active contests and lets the user enter and
/// view live standings.
class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen>
    with SingleTickerProviderStateMixin {
  String? _openContestId;

  @override
  Widget build(BuildContext context) {
    final contestsAsync = ref.watch(activeContestsProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF09031E), Color(0xFF1A0A40)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(),
              Expanded(
                child: contestsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: ZcColors.neonPurple),
                  ),
                  error: (e, _) => _ErrorView(message: e.toString()),
                  data: (contests) {
                    if (contests.isEmpty) {
                      return const _EmptyState();
                    }
                    if (_openContestId != null) {
                      final c = contests.firstWhere(
                          (c) => c.id == _openContestId,
                          orElse: () => contests.first);
                      return _StandingsView(
                        contest: c,
                        onBack: () =>
                            setState(() => _openContestId = null),
                      );
                    }
                    return RefreshIndicator(
                      color: ZcColors.gold,
                      backgroundColor: const Color(0xFF1A0B3D),
                      onRefresh: () async =>
                          ref.invalidate(activeContestsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                        itemCount: contests.length,
                        itemBuilder: (context, i) => _ContestCard(
                          contest: contests[i],
                          onViewStandings: () => setState(
                              () => _openContestId = contests[i].id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go('/events'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOURNAMENTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Compete. Win. Earn coins.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.emoji_events_rounded,
              color: ZcColors.gold, size: 26),
        ],
      ),
    );
  }
}

// =============================================================================
// CONTEST CARD
// =============================================================================

class _ContestCard extends ConsumerWidget {
  const _ContestCard({
    required this.contest,
    required this.onViewStandings,
  });

  final Contest contest;
  final VoidCallback onViewStandings;

  String _formatCountdown(Duration d) {
    if (d.inDays > 1) return '${d.inDays}d ${d.inHours.remainder(24)}h left';
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m left';
    }
    return '${d.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeLeft = contest.timeLeft;
    final isUrgent = timeLeft.inHours < 24;
    final timerColor =
        isUrgent ? const Color(0xFFEF4444) : const Color(0xFF4ADE80);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0B3D), Color(0xFF2A0E5C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZcColors.neonPurple.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: ZcColors.neonPurple.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + sponsor
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: ZcColors.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    contest.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (contest.sponsor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      contest.sponsor!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Scoring rules
            _ScoreRule(icon: '🏆', label: 'Win a match', points: '+3 pts'),
            const SizedBox(height: 5),
            _ScoreRule(
                icon: '🃏', label: 'Play any match', points: '+1 pt'),
            const SizedBox(height: 12),
            // Podium rewards
            const Text(
              'PRIZES',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PodiumPill('🥇 1st', '500 coins', const Color(0xFFD4AF37)),
                const SizedBox(width: 8),
                _PodiumPill('🥈 2nd', '300 coins',
                    const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                _PodiumPill('🥉 3rd', '150 coins',
                    const Color(0xFFCD7F32)),
              ],
            ),
            const SizedBox(height: 14),
            // Timer + buttons
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: timerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: timerColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          color: timerColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatCountdown(timeLeft),
                        style: TextStyle(
                          color: timerColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _EnterButton(contest: contest),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onViewStandings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: ZcColors.neonPurple.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Standings',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRule extends StatelessWidget {
  const _ScoreRule(
      {required this.icon,
      required this.label,
      required this.points});
  final String icon;
  final String label;
  final String points;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: ZcColors.neonPurple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(points,
              style: const TextStyle(
                  color: ZcColors.neonPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _PodiumPill extends StatelessWidget {
  const _PodiumPill(this.rank, this.reward, this.color);
  final String rank;
  final String reward;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(
          children: [
            Text(rank,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
            Text(reward,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ENTER BUTTON
// =============================================================================

class _EnterButton extends ConsumerStatefulWidget {
  const _EnterButton({required this.contest});
  final Contest contest;

  @override
  ConsumerState<_EnterButton> createState() => _EnterButtonState();
}

class _EnterButtonState extends ConsumerState<_EnterButton> {
  bool _loading = false;
  bool _entered = false;

  Future<void> _enter() async {
    if (_loading || _entered) return;
    setState(() => _loading = true);
    try {
      await ref.read(contestRepositoryProvider).enter(widget.contest.id);
      if (mounted) setState(() => _entered = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ZcColors.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _entered ? null : _enter,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _entered ? const Color(0xFF22C55E) : ZcColors.neonPurple,
        disabledBackgroundColor: const Color(0xFF22C55E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      ),
      child: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Text(
              _entered ? '✓ Entered' : 'Enter',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900),
            ),
    );
  }
}

// =============================================================================
// STANDINGS VIEW
// =============================================================================

class _StandingsView extends ConsumerWidget {
  const _StandingsView({
    required this.contest,
    required this.onBack,
  });

  final Contest contest;
  final VoidCallback onBack;

  Widget _avatarWidget(String id) {
    if (id.startsWith('av_')) return ZcAvatars.forId(id, 36);
    final opt = kAvatars.firstWhere((a) => a.id == id,
        orElse: () => kAvatars.first);
    return Image.asset(opt.asset,
        width: 36, height: 36, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync =
        ref.watch(contestStandingsProvider(contest.id));
    return Column(
      children: [
        // Mini back header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white70, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  contest.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: standingsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: ZcColors.neonPurple)),
            error: (e, _) =>
                Center(child: Text(e.toString(),
                    style: const TextStyle(color: Colors.white54))),
            data: (result) {
              final standings = result.standings;
              final myRank = result.myRank;
              if (standings.isEmpty) {
                return const Center(
                  child: Text('No players have entered yet.',
                      style: TextStyle(color: Colors.white38)),
                );
              }
              return Column(
                children: [
                  if (myRank > 0)
                    Container(
                      margin:
                          const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3A1280),
                            Color(0xFF1B0940)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: ZcColors.neonPurple
                                .withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded,
                              color: ZcColors.neonPurple, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Your rank: #$myRank',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      itemCount: standings.length,
                      itemBuilder: (context, i) {
                        final s = standings[i];
                        final medalEmoji = s.rank == 1
                            ? '🥇'
                            : s.rank == 2
                                ? '🥈'
                                : s.rank == 3
                                    ? '🥉'
                                    : null;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: s.isMe
                                ? const Color(0x22A855F7)
                                : const Color(0x12FFFFFF),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: s.isMe
                                  ? const Color(0x44A855F7)
                                  : const Color(0x12FFFFFF),
                              width: s.isMe ? 1.3 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Rank
                              SizedBox(
                                width: 36,
                                child: medalEmoji != null
                                    ? Text(medalEmoji,
                                        style: const TextStyle(
                                            fontSize: 18),
                                        textAlign: TextAlign.center)
                                    : Text(
                                        '#${s.rank}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              // Avatar placeholder (server doesn't
                              // join users in standings — just userId)
                              ClipOval(
                                child: ZcAvatars.forId(
                                    'av_default', 36),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s.isMe
                                      ? 'You'
                                      : 'Player ${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              // Score
                              Text(
                                '${s.score} pts',
                                style: const TextStyle(
                                  color: ZcColors.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded,
                color: Colors.white24, size: 60),
            SizedBox(height: 12),
            Text(
              'No active tournaments.\nCheck back soon!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      );
}
