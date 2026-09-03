import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/zc_bottom_nav.dart';
import '../../ui/zc_theme.dart';
import 'collection_data.dart';
import 'collection_widgets.dart';

/// Collection → Themes / Mind Spaces (light mockup with CURRENT THEME hero).
class ThemesScreenImpl extends ConsumerStatefulWidget {
  const ThemesScreenImpl({super.key});

  @override
  ConsumerState<ThemesScreenImpl> createState() => _ThemesScreenImplState();
}

class _ThemesScreenImplState extends ConsumerState<ThemesScreenImpl> {
  int _filter = 0;

  static const _filters = [
    'All',
    'Owned',
    'Premium',
    'Nature',
    'City',
    'Abstract',
  ];

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(collectionProvider)['themes']!;
    final items = switch (_filters[_filter]) {
      'Owned' => all.where((e) => e.owned).toList(),
      'Premium' => all.where((e) => !e.owned).toList(),
      'Rare' => all.where((e) => e.rarity == ZcRarity.rare).toList(),
      _ => all,
    };
    return Scaffold(
      backgroundColor: LcColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const CollectionHeader(
              icon: Icons.image_rounded,
              title: 'THEMES / MIND SPACES',
              subtitle: 'Change the vibe. Play in your style.',
              trailing: Icons.schedule_rounded,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _hero(),
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
                          crossAxisCount: 3,
                          mainAxisSpacing: 9,
                          crossAxisSpacing: 9,
                          childAspectRatio: 0.58,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _ThemeCard(
                            item: items[i], category: 'themes'),
                      ),
                    ),
                    const VisitStoreStrip(
                      icon: Icons.auto_awesome_rounded,
                      title: 'More themes in the Store!',
                      subtitle: 'Discover unique environments and mind '
                          'spaces.',
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

  Widget _hero() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 205,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LcColors.chipBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT THEME',
                      style: ZcText.body(10).copyWith(
                          color: LcColors.purple, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    child: Text('Cosmic Drift',
                        style: ZcText.heading(20)
                            .copyWith(color: LcColors.textDark)),
                  ),
                  const SizedBox(height: 4),
                  const RarityChip(rarity: ZcRarity.epic),
                  const SizedBox(height: 6),
                  Text('A vast space to focus,\nthink and win.',
                      style: ZcText.body(11.5)
                          .copyWith(color: LcColors.textMuted)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF8B46E8), Color(0xFF5B21B6)]),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Customize',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800)),
                        SizedBox(width: 4),
                        Icon(Icons.edit_rounded,
                            color: Colors.white, size: 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 150,
            height: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/art/th_galaxy.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF3B0764),
                    child: const Center(
                      child: Icon(Icons.style_rounded,
                          color: Color(0xFFFDE047), size: 36),
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.white, Color(0x00FFFFFF)],
                      stops: [0.0, 0.45],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: LcColors.chipBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: LcColors.purple, size: 13),
                        SizedBox(width: 4),
                        Text('In Use',
                            style: TextStyle(
                                color: LcColors.textDark,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({required this.item, required this.category});

  final CollectionItem item;
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(collectionProvider.notifier);
    return GestureDetector(
      onTap: () => ctrl.equip(category, item.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: item.equipped ? LcColors.purple : LcColors.chipBorder,
              width: item.equipped ? 1.8 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    item.asset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2E1065),
                      child: Center(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: () =>
                          ctrl.toggleFavorite(category, item.id),
                      child: item.equipped
                          ? const CircleAvatar(
                              radius: 10,
                              backgroundColor: LcColors.purple,
                              child: Icon(Icons.check_rounded,
                                  color: Colors.white, size: 13),
                            )
                          : Icon(
                              item.favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: item.favorite
                                  ? LcColors.purple
                                  : Colors.white,
                              size: 16,
                              shadows: const [
                                Shadow(
                                    color: Colors.black45, blurRadius: 4)
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: ZcText.body(11).copyWith(
                          color: LcColors.textDark,
                          fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(item.subtitle,
                      style: ZcText.body(8.5)
                          .copyWith(color: LcColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Row(
                    children: [
                      RarityChip(rarity: item.rarity),
                      const SizedBox(width: 6),
                      if (item.owned)
                        Row(
                          children: [
                            const Icon(Icons.lock_open_rounded,
                                size: 10, color: LcColors.textMuted),
                            const SizedBox(width: 3),
                            Text(item.equipped ? 'In Use' : 'Owned',
                                style: ZcText.body(8.5).copyWith(
                                    color: item.equipped
                                        ? LcColors.purple
                                        : LcColors.textMuted)),
                          ],
                        )
                      else ...[
                        Image.asset('assets/art/coin.png',
                            width: 11, height: 11),
                        const SizedBox(width: 3),
                        Text('${item.price ?? 0}',
                            style: ZcText.body(9.5)
                                .copyWith(color: LcColors.textDark)),
                      ],
                    ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
