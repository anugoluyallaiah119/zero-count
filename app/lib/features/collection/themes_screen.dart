import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/game/play_area_theme.dart';
import '../../ui/zc_bottom_nav.dart';
import '../../ui/zc_theme.dart';
import 'collection_data.dart';
import 'collection_widgets.dart';
import 'shop_repository.dart';

/// Map from collection item id → PlayAreaTheme so equipping updates the game.
final _themeMap = <String, PlayAreaTheme>{
  'th_brazil_carnival': PlayAreaTheme.brazilCarnival,
  'th_galaxy':          PlayAreaTheme.mysticGarden,
  'th_sakura':          PlayAreaTheme.sakuraJapan,
  'th_desert':          PlayAreaTheme.brazilCarnival,
  'th_zen':             PlayAreaTheme.sakuraJapan,
  'th_neon':            PlayAreaTheme.neonCyber,
  'th_atlantis':        PlayAreaTheme.mysticGarden,
  'th_felt':            PlayAreaTheme.mysticGarden,
  'th_ocean':           PlayAreaTheme.mysticGarden,
  'th_flow':            PlayAreaTheme.mysticGarden,
  'th_royal':           PlayAreaTheme.mysticGarden,
};

/// Returns the immersive background asset for a theme card preview.
String _previewAsset(CollectionItem item) => switch (item.id) {
      'th_brazil_carnival' => 'assets/art/play_area_bg_brazil.jpg',
      'th_galaxy'          => 'assets/art/th_galaxy.png',
      'th_sakura'          => 'assets/art/th_sakura_garden.png',
      'th_desert'          => 'assets/art/th_desert_dusk.png',
      'th_zen'             => 'assets/art/th_zen_garden.png',
      'th_neon'            => 'assets/art/th_neon_city.png',
      'th_atlantis'        => 'assets/art/th_atlantis.png',
      'th_felt'            => 'assets/art/th_classic_felt.png',
      'th_ocean'           => 'assets/art/th_ocean_depths.png',
      'th_flow'            => 'assets/art/th_abstract_flow.png',
      'th_royal'           => 'assets/art/th_royal_casino.png',
      _                    => item.asset,
    };

class ThemesScreenImpl extends ConsumerStatefulWidget {
  const ThemesScreenImpl({super.key});

  @override
  ConsumerState<ThemesScreenImpl> createState() => _ThemesScreenImplState();
}

class _ThemesScreenImplState extends ConsumerState<ThemesScreenImpl> {
  int _filter = 0;

  static const _filters = ['All', 'Owned', 'Premium'];

  @override
  Widget build(BuildContext context) {
    final all   = ref.watch(collectionProvider)['themes']!;
    final items = switch (_filters[_filter]) {
      'Owned'   => all.where((e) => e.owned).toList(),
      'Premium' => all.where((e) => !e.owned).toList(),
      _         => all,
    };

    return Scaffold(
      backgroundColor: LcColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const CollectionHeader(
              icon: Icons.image_rounded,
              title: 'THEMES',
              subtitle: 'Change the vibe. Play in your style.',
              trailing: Icons.schedule_rounded,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _HeroCard(),
                    const SizedBox(height: 12),
                    CollectionFilters(
                      filters: _filters,
                      active: _filter,
                      onChanged: (i) => setState(() => _filter = i),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.38,
                        ),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) =>
                            _ThemeCard(item: items[i]),
                      ),
                    ),
                    const VisitStoreStrip(
                      icon: Icons.auto_awesome_rounded,
                      title: 'More themes coming soon!',
                      subtitle: 'New environments added regularly.',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          const ZcBottomNav(active: ZcNavTab.collection, dark: false),
    );
  }
}

// ── Hero banner: shows currently equipped theme ────────────────────────────

class _HeroCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipped = ref.watch(collectionProvider)['themes']!
        .firstWhere((e) => e.equipped,
            orElse: () => ref.watch(collectionProvider)['themes']!.first);
    final previewAsset = _previewAsset(equipped);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LcColors.chipBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed background preview
          Image.asset(previewAsset, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFF0D6E38))),
          // Left text overlay gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xEE09031E), Color(0x00000000)],
                stops: [0.0, 0.65],
              ),
            ),
          ),
          // Text content
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            right: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CURRENT THEME',
                    style: ZcText.body(9).copyWith(
                        color: LcColors.purple,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(equipped.name,
                    style: ZcText.heading(18)
                        .copyWith(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                RarityChip(rarity: equipped.rarity),
                const SizedBox(height: 6),
                Text(equipped.subtitle,
                    style: ZcText.body(10.5)
                        .copyWith(color: Colors.white60),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Brazil/Japan hero table overlay inset
          if (equipped.id == 'th_brazil_carnival')
            Positioned(
              right: 8,
              bottom: 8,
              top: 8,
              width: 90,
              child: Image.asset(
                'assets/art/play_area_table_brazil.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            )
          else if (equipped.id == 'th_sakura' || equipped.id == 'th_zen')
            Positioned(
              right: 8,
              bottom: 8,
              top: 8,
              width: 90,
              child: _JapanTablePreview(),
            ),
        ],
      ),
    );
  }
}

// ── Theme grid card ────────────────────────────────────────────────────────

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({required this.item});
  final CollectionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(collectionProvider.notifier);
    final preview = _previewAsset(item);
    final isBrazil = item.id == 'th_brazil_carnival';
    final isJapan = item.id == 'th_sakura' || item.id == 'th_zen';

    return GestureDetector(
      onTap: () async {
        if (!item.owned) {
          // Buy flow
          try {
            await ref.read(shopCatalogProvider.notifier).buy(item.id);
            ctrl.markOwned('themes', item.id);
            ctrl.equip('themes', item.id);
            if (_themeMap[item.id] != null) {
              ref.read(equippedThemeProvider.notifier)
                  .setTheme(_themeMap[item.id]!);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(e.toString()),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }
          return;
        }
        // Equip — updates both collection state and active game theme
        ctrl.equip('themes', item.id);
        if (_themeMap[item.id] != null) {
          ref.read(equippedThemeProvider.notifier)
              .setTheme(_themeMap[item.id]!);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.equipped ? LcColors.purple : LcColors.chipBorder,
            width: item.equipped ? 2.0 : 1,
          ),
          boxShadow: item.equipped
              ? [BoxShadow(
                  color: LcColors.purple.withValues(alpha: 0.2),
                  blurRadius: 10, spreadRadius: 1)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background preview image
            Image.asset(preview, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF2E1065))),

            // Brazil table overlay — shows in-game table shape
            if (isBrazil)
              Positioned(
                right: -10,
                bottom: -10,
                width: 80,
                height: 80,
                child: Opacity(
                  opacity: 0.85,
                  child: Image.asset(
                    'assets/art/play_area_table_brazil.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Japan tatami table overlay
            if (isJapan)
              Positioned(
                right: -6,
                bottom: -6,
                width: 72,
                height: 72,
                child: Opacity(
                  opacity: 0.80,
                  child: _JapanTablePreview(),
                ),
              ),

            // Dark gradient bottom for text legibility
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(9, 20, 9, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xDD000000), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        RarityChip(rarity: item.rarity),
                        const SizedBox(width: 6),
                        if (item.owned)
                          Text(
                            item.equipped ? '✓ In Use' : 'Owned',
                            style: TextStyle(
                              color: item.equipped
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white60,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else ...[
                          Image.asset('assets/art/coin.png',
                              width: 11, height: 11,
                              errorBuilder: (_, __, ___) => const Text(
                                  '🪙', style: TextStyle(fontSize: 10))),
                          const SizedBox(width: 3),
                          Text('${item.price ?? 0}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Equipped checkmark top-left
            if (item.equipped)
              Positioned(
                top: 6, left: 6,
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: LcColors.purple, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13),
                ),
              ),

            // Lock / heart / favorite top-right
            if (!item.equipped)
              Positioned(
                top: 5, right: 5,
                child: GestureDetector(
                  onTap: () => ref
                      .read(collectionProvider.notifier)
                      .toggleFavorite('themes', item.id),
                  child: Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0x99000000), shape: BoxShape.circle),
                    child: Icon(
                      !item.owned
                          ? Icons.lock_rounded
                          : item.favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                      color: item.favorite && item.owned
                          ? Colors.pink
                          : Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tatami-style table miniature with Enso circle for Japan theme previews.
class _JapanTablePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC2D1A00),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x88E8A4B8), width: 1),
      ),
      child: CustomPaint(painter: _MiniEnsoPainter()),
    );
  }
}

class _MiniEnsoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.35;

    final paint = Paint()
      ..color = const Color(0x66E8A4B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -pi * 0.7,
      pi * 1.85,
      false,
      paint,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: '零',
        style: TextStyle(fontSize: 14, color: Color(0x88E8A4B8), fontWeight: FontWeight.w900, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
