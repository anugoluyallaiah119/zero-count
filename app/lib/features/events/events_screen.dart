import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_bottom_nav.dart';
import '../../ui/zc_header.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import '../player/profile_repository.dart';
import 'contest_repository.dart';

/// Events hub — Daily / Weekly / Monthly / Sponsored tabs (Phase 2 mockups).
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  late int _tab = widget.initialTab;

  static const _tabs = ['Daily', 'Weekly', 'Monthly', 'Sponsored'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZcColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const EventsHeader(),
              const SizedBox(height: 10),
              _tabBar(),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: switch (_tab) {
                    0 => const _DailyTab(),
                    1 => const _WeeklyTab(),
                    2 => const _MonthlyTab(),
                    _ => const _SponsoredTab(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const ZcBottomNav(active: ZcNavTab.events),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text('EVENTS',
              style: ZcText.display(15).copyWith(letterSpacing: 0.8)),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0x6613083C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          key: Key('eventsTab$i'),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: i == _tab
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF7B2FE0),
                                      Color(0xFF4A15A0)
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                child: Text(
                                  _tabs[i],
                                  style: TextStyle(
                                    color: i == _tab
                                        ? Colors.white
                                        : ZcColors.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              CircleAvatar(
                                radius: 2,
                                backgroundColor: i == _tab
                                    ? Colors.white
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header shared by the Events tabs: avatar + greeting + level, centered
/// logo, currency pills, notification bell.
class EventsHeader extends ConsumerWidget {
  const EventsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: ZcColors.neonPurple,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: ZcColors.panelInput,
              backgroundImage: (p?.avatar.isNotEmpty ?? false)
                  ? AssetImage(avatarAsset(p!.avatar))
                  : null,
              child: (p?.avatar.isEmpty ?? true)
                  ? const Icon(Icons.person_rounded,
                      color: Colors.white, size: 22)
                  : null,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${p?.displayName ?? 'Player'}!',
                    style: ZcText.heading(13.5),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                FittedBox(
                  child: Row(
                    children: [
                      Text('Level ${p?.level ?? 1}',
                          style: ZcText.body(10.5)
                              .copyWith(color: ZcColors.gemPurple)),
                      const SizedBox(width: 6),
                      Container(
                        width: 52,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0x33FFFFFF),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (p?.levelProgress ?? 0).clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF9B30FF),
                                Color(0xFFD846CB),
                              ]),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Image.asset(
            'assets/art/logo.png',
            height: 28,
            errorBuilder: (_, __, ___) => const Text(
              'ZERO COUNT',
              style: TextStyle(
                color: Color(0xFFFDE047),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          ZcCurrencyPill(
              asset: 'assets/art/coin.png', value: '${p?.coins ?? 0}'),
          const SizedBox(width: 5),
          ZcCurrencyPill(
              asset: 'assets/art/gem.png', value: '${p?.gems ?? 0}'),
          const SizedBox(width: 6),
          const _Bell(),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x990D0330),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: const Icon(Icons.notifications_rounded,
              color: Colors.white, size: 17),
        ),
        const Positioned(
          right: 2,
          top: 2,
          child: CircleAvatar(radius: 3.5, backgroundColor: ZcColors.errorRed),
        ),
      ],
    );
  }
}

/// Hero banner: big title left, subtitle with purple accent word, refresh
/// chip, generated art on the right.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.line1,
    required this.line2Prefix,
    required this.accent,
    required this.chipLabel,
    required this.chipValue,
    required this.art,
  });

  final String title;
  final String line1;
  final String line2Prefix;
  final String accent;
  final String chipLabel;
  final String chipValue;
  final String art;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x5513083C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    child: Text(title, style: ZcText.display(24)),
                  ),
                  const SizedBox(height: 6),
                  Text(line1, style: ZcText.body(12.5)),
                  RichText(
                    text: TextSpan(
                      style: ZcText.body(12.5),
                      children: [
                        TextSpan(text: line2Prefix),
                        TextSpan(
                          text: accent,
                          style: const TextStyle(color: ZcColors.gemPurple),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x880D0330),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                color: ZcColors.gemPurple, size: 14),
                            const SizedBox(width: 6),
                            Text(chipLabel,
                                style: ZcText.body(9.5)
                                    .copyWith(letterSpacing: 0.8)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(chipValue,
                            style: ZcText.heading(14)
                                .copyWith(color: ZcColors.gemPurple)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    art,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF3B0764),
                      child: const Center(
                        child: Icon(
                          Icons.event_available_rounded,
                          size: 48,
                          color: Color(0xFFFDE047),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDef {
  const _EventDef({
    required this.icon,
    required this.title,
    required this.desc,
    required this.progress,
    required this.total,
    required this.coins,
    required this.gems,
    required this.action,
    required this.color,
    this.unlockIn,
    this.barColor = const Color(0xFF9B30FF),
  });

  final String icon;
  final String title;
  final String desc;
  final int progress;
  final int total;
  final int coins;
  final int gems;
  final String action;
  final Color color;
  final String? unlockIn;
  final Color barColor;
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.def});

  final _EventDef def;

  @override
  Widget build(BuildContext context) {
    final locked = def.unlockIn != null;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x6613083C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Title & Description
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  def.icon,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFF3B0764),
                    child: const Icon(Icons.stars_rounded,
                        color: Color(0xFFFDE047), size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.title,
                        style: ZcText.heading(13.5).copyWith(letterSpacing: 0.4)),
                    const SizedBox(height: 2),
                    Text(
                      def.desc,
                      style: ZcText.body(11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (def.progress / def.total).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0x22FFFFFF),
                    valueColor: AlwaysStoppedAnimation(def.barColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${def.progress}/${def.total}',
                style: ZcText.body(11).copyWith(color: ZcColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Rewards + Action Button (Responsive & Never Overflows)
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/art/coin.png',
                    width: 15,
                    height: 15,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on,
                      size: 15,
                      color: Color(0xFFFACC15),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text('${def.coins}', style: ZcText.heading(12)),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/art/gem.png',
                    width: 15,
                    height: 15,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.diamond,
                      size: 15,
                      color: Color(0xFFC084FC),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text('${def.gems}', style: ZcText.heading(12)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: locked ? const Color(0x33000000) : def.color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: locked
                            ? const Color(0x22FFFFFF)
                            : def.color.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (locked) ...[
                          const Icon(Icons.lock_rounded,
                              color: ZcColors.textSecondary, size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          def.action,
                          style: ZcText.heading(11.5).copyWith(
                            color: locked
                                ? ZcColors.textSecondary
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(height: 3),
                    Text(
                      def.unlockIn!,
                      style: ZcText.body(9).copyWith(color: ZcColors.gemPurple),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom strip: completed count ring + milestone rewards track.
class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.count,
    required this.countLabel,
    required this.title,
    required this.subtitle,
    required this.milestones,
  });

  final String count;
  final String countLabel;
  final String title;
  final String subtitle;
  final List<({String asset, String value, bool done})> milestones;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x6613083C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZcColors.neonPurple.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: ZcColors.neonPurple, width: 2.4),
                ),
                child: Center(
                  child: Text(count, style: ZcText.display(17)),
                ),
              ),
              const SizedBox(height: 3),
              Text(countLabel,
                  style: ZcText.body(7.5).copyWith(letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ZcText.heading(12.5).copyWith(letterSpacing: 0.5)),
                Text(subtitle, style: ZcText.body(10), maxLines: 2),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < milestones.length; i++) ...[
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 3,
                            color: milestones[i - 1].done
                                ? ZcColors.neonGreen
                                : const Color(0x22FFFFFF),
                          ),
                        ),
                      Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0x880D0330),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0x22FFFFFF)),
                                ),
                                child: Image.asset(
                                  milestones[i].asset,
                                  width: 18,
                                  height: 18,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: Color(0xFFFDE047),
                                    size: 18,
                                  ),
                                ),
                              ),
                              if (milestones[i].value.isNotEmpty)
                                Positioned(
                                  right: -2,
                                  bottom: -3,
                                  child: Text(
                                    milestones[i].value,
                                    style: ZcText.body(8).copyWith(
                                        color: ZcColors.textPrimary),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          CircleAvatar(
                            radius: 6.5,
                            backgroundColor: milestones[i].done
                                ? ZcColors.neonGreen
                                : const Color(0x33FFFFFF),
                            child: milestones[i].done
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.black, size: 9)
                                : null,
                          ),
                        ],
                      ),
                    ],
                    Expanded(
                        child: Container(height: 3, color: Colors.transparent)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: ZcColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}

class _DailyTab extends StatelessWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Hero(
          title: 'DAILY EVENTS',
          line1: 'Play. Complete. Earn.',
          line2Prefix: 'New events ',
          accent: 'everyday!',
          chipLabel: 'REFRESHES IN',
          chipValue: '09h : 42m : 15s',
          art: 'assets/art/hero_daily.png',
        ),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_card_fan.png',
                title: 'DAILY PLAY',
                desc: 'Play 3 matches today',
                progress: 2,
                total: 3,
                coins: 150,
                gems: 10,
                action: 'CONTINUE',
                color: Color(0xFF7B2FE0))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_people.png',
                title: 'GROUP MASTER',
                desc: 'Make 4 groups in any match',
                progress: 3,
                total: 4,
                coins: 200,
                gems: 15,
                action: 'GO NOW',
                color: Color(0xFF1565E8),
                barColor: Color(0xFF2EC5F6))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_flame_zero.png',
                title: 'ZERO STREAK',
                desc: 'Win 2 matches today',
                progress: 1,
                total: 2,
                coins: 250,
                gems: 20,
                action: 'PLAY NOW',
                color: Color(0xFFE88A15),
                barColor: Color(0xFFF9A809))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_stopwatch.png',
                title: 'SPEED ROUND',
                desc: 'Win 1 match under 5 minutes',
                progress: 0,
                total: 1,
                coins: 150,
                gems: 10,
                action: 'LOCKED',
                color: Color(0xFF18B84A),
                unlockIn: 'Unlocks in 02h 12m',
                barColor: Color(0xFF2EEA6A))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_crystal_zero.png',
                title: 'DAILY ZERO',
                desc: 'Score Zero Count in 1 round',
                progress: 0,
                total: 1,
                coins: 300,
                gems: 25,
                action: 'LOCKED',
                color: Color(0xFF7B2FE0),
                unlockIn: 'Unlocks in 06h 12m')),
        _ProgressStrip(
          count: '3',
          countLabel: 'COMPLETED',
          title: 'DAILY PROGRESS',
          subtitle: 'Complete more events to unlock bonus rewards!',
          milestones: [
            (asset: 'assets/art/gem.png', value: '15', done: true),
            (asset: 'assets/art/coin.png', value: '300', done: true),
            (asset: 'assets/art/sp_reverse.png', value: '1', done: true),
            (asset: 'assets/art/gift_box.png', value: '1', done: false),
          ],
        ),
      ],
    );
  }
}

class _WeeklyTab extends StatelessWidget {
  const _WeeklyTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Hero(
          title: 'WEEKLY EVENTS',
          line1: 'Bigger goals. Better rewards.',
          line2Prefix: 'New weekly events ',
          accent: 'every Monday!',
          chipLabel: 'WEEK ENDS IN',
          chipValue: '03d : 14h : 42m',
          art: 'assets/art/hero_weekly.png',
        ),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_trophy_gold.png',
                title: 'WEEKLY CHAMPION',
                desc: 'Win 10 matches this week',
                progress: 6,
                total: 10,
                coins: 500,
                gems: 50,
                action: 'CONTINUE',
                color: Color(0xFF7B2FE0))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_podium.png',
                title: 'TEAM PLAY',
                desc: 'Play 20 matches in any mode',
                progress: 12,
                total: 20,
                coins: 400,
                gems: 40,
                action: 'GO NOW',
                color: Color(0xFF1565E8),
                barColor: Color(0xFF2EC5F6))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_hex_zero.png',
                title: 'ZERO MASTER',
                desc: 'Score Zero Count in 15 rounds',
                progress: 8,
                total: 15,
                coins: 600,
                gems: 60,
                action: 'PLAY NOW',
                color: Color(0xFF12A89E),
                barColor: Color(0xFF2EEA6A))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_stopwatch_orange.png',
                title: 'QUICK THINKER',
                desc: 'Win 5 matches in under 5 minutes',
                progress: 2,
                total: 5,
                coins: 300,
                gems: 30,
                action: 'GO NOW',
                color: Color(0xFFE88A15),
                barColor: Color(0xFFF9A809))),
        _EventCard(
            def: _EventDef(
                icon: 'assets/art/ev_lock_shield.png',
                title: 'WEEKLY STREAK',
                desc: 'Win matches on 7 different days',
                progress: 0,
                total: 7,
                coins: 700,
                gems: 70,
                action: 'LOCKED',
                color: Color(0xFF7B2FE0),
                unlockIn: 'Unlocks in 2d 14h')),
        _ProgressStrip(
          count: '2',
          countLabel: 'COMPLETED',
          title: 'WEEKLY PROGRESS',
          subtitle: 'Complete more events to unlock milestone rewards!',
          milestones: [
            (asset: 'assets/art/gem.png', value: '25', done: true),
            (asset: 'assets/art/coin.png', value: '400', done: true),
            (asset: 'assets/art/sp_shield.png', value: '1', done: true),
            (asset: 'assets/art/gift_box.png', value: '1', done: false),
          ],
        ),
      ],
    );
  }
}

class _MonthlyTab extends StatelessWidget {
  const _MonthlyTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Hero(
          title: 'MONTHLY EVENTS',
          line1: 'Big prizes. Bigger moments.',
          line2Prefix: 'New events ',
          accent: 'every month!',
          chipLabel: 'MONTH ENDS IN',
          chipValue: '18d : 09h : 41m',
          art: 'assets/art/hero_monthly.png',
        ),
        // Live tournaments banner — wired to real /api/contests data.
        const _LiveTournamentsBanner(),
        _monthlyCard(
          icon: 'assets/art/ev_cup_premium.png',
          premium: true,
          title: 'MONTHLY CHAMPIONSHIP',
          desc: 'Compete with the best and be the Zero Count Champion!',
          progress: 62,
          total: 100,
          coins: '10,000',
          gems: '500',
          action: 'CONTINUE',
          color: const Color(0xFF7B2FE0),
        ),
        _monthlyCard(
          icon: 'assets/art/ev_people.png',
          title: 'TEAM DOMINATION',
          desc: 'Play in teams and earn massive rewards together!',
          progress: 28,
          total: 50,
          coins: '5,000',
          gems: '300',
          action: 'JOIN NOW',
          color: const Color(0xFF1565E8),
          barColor: const Color(0xFF2EC5F6),
        ),
        _monthlyCard(
          icon: 'assets/art/ev_hex_zero.png',
          title: 'ZERO MASTER QUEST',
          desc: 'Be the Zero Master this month and unlock exclusive rewards!',
          progress: 12,
          total: 15,
          coins: '7,500',
          gems: '400',
          action: 'PLAY NOW',
          color: const Color(0xFF18B84A),
          barColor: const Color(0xFF2EEA6A),
        ),
        _monthlyCard(
          icon: 'assets/art/ev_stopwatch_orange.png',
          title: 'SPEED CHALLENGE',
          desc: 'Fastest minds win the biggest monthly rewards!',
          progress: 45,
          total: 100,
          coins: '3,000',
          gems: '200',
          action: 'GO NOW',
          color: const Color(0xFFE88A15),
          barColor: const Color(0xFFF9A809),
        ),
        _monthlyCard(
          icon: 'assets/art/ev_lock_hex.png',
          title: 'MYSTERY MAYHEM',
          desc: 'A mystery event coming soon. Something epic awaits!',
          coins: '???',
          gems: '???',
          action: 'LOCKED',
          color: const Color(0xFF7B2FE0),
          unlockIn: 'Starts in 08d 09h',
        ),
        const _ProgressStrip(
          count: '230',
          countLabel: 'POINTS',
          title: 'MONTHLY PROGRESS',
          subtitle: 'Play more events to unlock milestone rewards!',
          milestones: [
            (asset: 'assets/art/gem.png', value: '50', done: true),
            (asset: 'assets/art/coin.png', value: '500', done: true),
            (asset: 'assets/art/sp_mirror.png', value: '1', done: true),
            (asset: 'assets/art/gift_box.png', value: '1,200', done: false),
          ],
        ),
      ],
    );
  }

  Widget _monthlyCard({
    required String icon,
    required String title,
    required String desc,
    required String coins,
    required String gems,
    required String action,
    required Color color,
    bool premium = false,
    int? progress,
    int? total,
    String? unlockIn,
    Color barColor = const Color(0xFF9B30FF),
  }) {
    final locked = unlockIn != null;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x6613083C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  icon,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFF3B0764),
                    child: const Icon(Icons.stars_rounded,
                        color: Color(0xFFFDE047), size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (premium)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZcColors.neonPurple,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('PREMIUM',
                            style: ZcText.heading(8).copyWith(letterSpacing: 1)),
                      ),
                    Text(title,
                        style:
                            ZcText.heading(13).copyWith(letterSpacing: 0.4)),
                    const SizedBox(height: 2),
                    Text(desc, style: ZcText.body(11), maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null && total != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / total).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0x22FFFFFF),
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$progress/$total',
                    style: ZcText.body(11).copyWith(color: ZcColors.textPrimary)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/art/coin.png',
                    width: 15,
                    height: 15,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on,
                      size: 15,
                      color: Color(0xFFFACC15),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(coins, style: ZcText.heading(12)),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/art/gem.png',
                    width: 15,
                    height: 15,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.diamond,
                      size: 15,
                      color: Color(0xFFC084FC),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(gems, style: ZcText.heading(12)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: locked ? const Color(0x33000000) : color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (locked) ...[
                          const Icon(Icons.lock_rounded,
                              color: ZcColors.textSecondary, size: 12),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          action,
                          style: ZcText.heading(11.5).copyWith(
                            color: locked
                                ? ZcColors.textSecondary
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unlockIn != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      unlockIn,
                      style: ZcText.body(9).copyWith(color: ZcColors.gemPurple),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banner in the Monthly tab that surfaces live /api/contests data.
class _LiveTournamentsBanner extends ConsumerWidget {
  const _LiveTournamentsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeContestsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (contests) {
        if (contests.isEmpty) return const SizedBox.shrink();
        final c = contests.first;
        final timeLeft = c.timeLeft;
        final days = timeLeft.inDays;
        final hours = timeLeft.inHours.remainder(24);
        return GestureDetector(
          onTap: () => context.push('/tournaments'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A0E5C), Color(0xFF1A0840)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0x66A855F7), width: 1.2),
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${days}d ${hours}h remaining · Win = +3 pts',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5A1FA8), Color(0xFF3A1280)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'VIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SponsoredTab extends StatelessWidget {
  const _SponsoredTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Hero(
          title: 'SPONSORED EVENTS',
          line1: 'Play with top brands.',
          line2Prefix: 'Win ',
          accent: 'real-world rewards!',
          chipLabel: 'REFRESHES IN',
          chipValue: '05d : 12h : 18m',
          art: 'assets/art/hero_sponsored.png',
        ),
        _sponsoredBrandCard(
          brandLogo: 'assets/art/brand_swiggy.png',
          brandName: 'Swiggy',
          title: 'SWIGGY FOOD FEST',
          desc: 'Win matches to get ₹100 Swiggy vouchers & special discount codes!',
          action: 'PLAY NOW',
          color: const Color(0xFFFC8019),
          voucher: '₹100 Voucher',
        ),
        _sponsoredBrandCard(
          brandLogo: 'assets/art/brand_boat.png',
          brandName: 'boAt',
          title: 'BOAT BEAT CHALLENGE',
          desc: 'Score top in weekly leaderboard to win boAt Airdopes & headphones!',
          action: 'JOIN NOW',
          color: const Color(0xFFE50914),
          voucher: 'boAt Airdopes',
        ),
        _sponsoredBrandCard(
          brandLogo: 'assets/art/brand_sprite.png',
          brandName: 'Sprite',
          title: 'CLEAR HAI REFRESH',
          desc: 'Score 5 Zero Counts today and get exciting merch coupons!',
          action: 'GO NOW',
          color: const Color(0xFF008B45),
          voucher: 'Merch Coupon',
        ),
        _sponsoredBrandCard(
          brandLogo: 'assets/art/brand_intel.png',
          brandName: 'Intel',
          title: 'INTEL GAMER DAYS',
          desc: 'Play ranked matches to qualify for Intel Gaming Grand Finals!',
          action: 'REGISTER',
          color: const Color(0xFF0071C5),
          voucher: 'Grand Pass',
        ),
      ],
    );
  }

  Widget _sponsoredBrandCard({
    required String brandLogo,
    required String brandName,
    required String title,
    required String desc,
    required String action,
    required Color color,
    required String voucher,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x6613083C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  brandLogo,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF3B0764),
                    child: Center(
                      child: Text(
                        brandName.isNotEmpty ? brandName[0] : '★',
                        style: const TextStyle(
                          color: Color(0xFFFDE047),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style:
                            ZcText.heading(13).copyWith(letterSpacing: 0.4)),
                    const SizedBox(height: 2),
                    Text(desc, style: ZcText.body(11), maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_giftcard_rounded,
                        color: Color(0xFFFDE047), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      voucher,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  action,
                  style: ZcText.heading(11.5).copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
