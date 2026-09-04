import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/zc_bottom_nav.dart';
import '../../ui/zc_theme.dart';
import 'collection_data.dart';
import 'collection_widgets.dart';
import 'themes_screen.dart';

/// Shared Collection grid screen (Card Backs / Avatars / Effects / Stickers /
/// Special Cards) driven by [GridScreenConfig].
class CollectionGridScreen extends ConsumerStatefulWidget {
  const CollectionGridScreen({
    super.key,
    required this.config,
    this.embedded = false,
  });

  final GridScreenConfig config;

  /// When true, renders body content only — no Scaffold, no CollectionHeader,
  /// no BottomNav. Used by the Store tab to host a category inline.
  final bool embedded;

  @override
  ConsumerState<CollectionGridScreen> createState() =>
      _CollectionGridScreenState();
}

class GridScreenConfig {
  const GridScreenConfig({
    required this.category,
    required this.headerIcon,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.heroEyebrow,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.heroArt,
    required this.heroRarity,
    required this.filters,
    this.stripIcon = Icons.shopping_bag_rounded,
    required this.stripTitle,
    required this.stripSubtitle,
    this.heroAction = 'Customize',
    this.heroDark = false,
    this.showTabBar = false,
    this.tabActive = '',
    this.showCollectionHeader = false,
    this.heroBadge = 'Epic',
    this.crossAxisCount = 4,
    this.artAspect = 0.82,
    this.showOwnedBadge = false,
    this.trailing = Icons.lock_rounded,
  });

  final String category;
  final IconData headerIcon;
  final String headerTitle;
  final String headerSubtitle;
  final String heroEyebrow;
  final String heroTitle;
  final String heroSubtitle;
  final String heroArt;
  final ZcRarity heroRarity;
  final String heroBadge;
  final String heroAction;
  final bool heroDark;
  final bool showTabBar;
  final String tabActive;

  /// Card Backs mockup: profile-style header + COLLECTION title instead.
  final bool showCollectionHeader;
  final List<String> filters;
  final IconData stripIcon; // icon shown on the Visit Store strip
  final String stripTitle;
  final String stripSubtitle;
  final int crossAxisCount;
  final double artAspect;
  final bool showOwnedBadge;
  final IconData trailing;
}

class _CollectionGridScreenState
    extends ConsumerState<CollectionGridScreen> {
  int _filter = 0;

  GridScreenConfig get c => widget.config;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(collectionProvider)[c.category]!;
    final items = _filtered(all);
    if (widget.embedded) {
      // Store-tab embed: chrome comes from the host (Scaffold, header,
      // category chips, bottom nav). Return the scrollable body only.
      return SingleChildScrollView(
        child: c.heroDark
            ? Column(
                children: [
                  _hero(all),
                  const SizedBox(height: 16),
                  Container(
                    decoration: const BoxDecoration(
                      color: LcColors.bg,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26)),
                    ),
                    padding: const EdgeInsets.only(top: 14),
                    child: _gridSection(items),
                  ),
                ],
              )
            : _gridSection(items),
      );
    }
    return Scaffold(
      backgroundColor: c.heroDark ? ZcColors.bgBottom : LcColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            if (c.showCollectionHeader) ...[
              const EventsHeaderLight(),
              const SizedBox(height: 10),
              _collectionTitleRow(),
              const SizedBox(height: 6),
              CollectionTabBar(active: c.tabActive),
            ] else
              CollectionHeader(
                icon: c.headerIcon,
                title: c.headerTitle,
                subtitle: c.headerSubtitle,
                trailing: c.trailing,
                dark: c.heroDark,
              ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: c.heroDark
                    ? Column(
                        children: [
                          _hero(all),
                          const SizedBox(height: 16),
                          Container(
                            decoration: const BoxDecoration(
                              color: LcColors.bg,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(26)),
                            ),
                            padding: const EdgeInsets.only(top: 14),
                            child: _gridSection(items),
                          ),
                        ],
                      )
                    : _gridSection(items),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          const ZcBottomNav(active: ZcNavTab.collection, dark: false),
    );
  }

  Widget _gridSection(List<CollectionItem> items) {
    return Column(
      children: [
        if (!c.heroDark) ...[
          _hero(ref.watch(collectionProvider)[c.category]!),
          const SizedBox(height: 12),
        ],
        CollectionFilters(
          filters: c.filters,
          active: _filter,
          onChanged: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: c.crossAxisCount,
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: _childAspect(),
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => CollectionGridCard(
              category: c.category,
              item: items[i],
              artAspect: c.artAspect,
              showOwnedBadge: c.showOwnedBadge,
            ),
          ),
        ),
        VisitStoreStrip(
          icon: c.stripIcon,
          title: c.stripTitle,
          subtitle: c.stripSubtitle,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  double _childAspect() {
    // card height ≈ artHeight + ~56 for texts
    // width = (screenW - 28 - (n-1)*9)/n ; solve at 426 logical width.
    const w = 426.0;
    final cellW = (w - 28 - (c.crossAxisCount - 1) * 9) / c.crossAxisCount;
    final artH = cellW / c.artAspect;
    final extra = c.showOwnedBadge ? 74.0 : 58.0;
    return cellW / (artH + extra);
  }

  List<CollectionItem> _filtered(List<CollectionItem> all) {
    if (_filter == 0) return all;
    final f = c.filters[_filter];
    return switch (f) {
      'Owned' => all.where((e) => e.owned).toList(),
      'Favorites' => all.where((e) => e.favorite).toList(),
      'Rare' => all.where((e) => e.rarity == ZcRarity.rare).toList(),
      'Epic' => all.where((e) => e.rarity == ZcRarity.epic).toList(),
      'Legendary' =>
        all.where((e) => e.rarity == ZcRarity.legendary).toList(),
      'Premium' => all.where((e) => !e.owned).toList(),
      _ => all,
    };
  }

  Widget _collectionTitleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text('COLLECTION',
              style: ZcText.display(16).copyWith(color: LcColors.textDark)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LcColors.chipBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 14, color: LcColors.textMuted),
                SizedBox(width: 5),
                Text('My Inventory',
                    style: TextStyle(
                        color: LcColors.textDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
                Icon(Icons.chevron_right_rounded,
                    size: 14, color: LcColors.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(List<CollectionItem> all) {
    final owned = all.where((e) => e.owned).length;
    final dark = c.heroDark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: dark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1D0A4B), Color(0xFF0D0328)],
              )
            : null,
        color: dark ? null : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: dark ? const Color(0x33FFFFFF) : LcColors.chipBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.52,
                child: Image.asset(
                  c.heroArt,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF3B0764),
                    child: const Center(
                      child: Icon(Icons.style_rounded,
                          size: 48, color: Color(0xFFFDE047)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: dark
                      ? const [Color(0xF2140740), Color(0x00140740)]
                      : const [Colors.white, Color(0x00FFFFFF)],
                  stops: const [0.5, 0.95],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.heroEyebrow.isNotEmpty) ...[
                  Text(c.heroEyebrow,
                      style: ZcText.body(10).copyWith(
                          color: LcColors.purple, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    Flexible(
                      child: Text(c.heroTitle,
                          style: ZcText.heading(20).copyWith(
                              color: dark
                                  ? Colors.white
                                  : LcColors.textDark),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (!c.showCollectionHeader) ...[
                      const SizedBox(width: 8),
                      RarityChip(rarity: c.heroRarity),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(c.heroSubtitle,
                    style: ZcText.body(11.5).copyWith(
                        color:
                            dark ? ZcColors.textSecondary : LcColors.textMuted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!c.showCollectionHeader)
                      Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: dark ? Colors.white : null,
                        gradient: dark
                            ? null
                            : const LinearGradient(colors: [
                                Color(0xFF8B46E8),
                                Color(0xFF5B21B6),
                              ]),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(c.heroAction,
                              style: TextStyle(
                                  color: dark
                                      ? LcColors.purpleDark
                                      : Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded,
                              color: dark ? LcColors.purpleDark : Colors.white,
                              size: 13),
                        ],
                      ),
                    ),
                    if (c.showCollectionHeader) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: LcColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: LcColors.chipBorder),
                        ),
                        child: FittedBox(
                          child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 13, color: LcColors.purple),
                            const SizedBox(width: 5),
                            Text('$owned / ${all.length} Collected',
                                style: const TextStyle(
                                    color: LcColors.textDark,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800)),
                          ],
                          ),
                        ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (dark)
            const Positioned(
              right: 14,
              bottom: 12,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: LcColors.purple,
                child: Icon(Icons.check_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
        ],
      ),
    );
  }
}

/// Concrete screens --------------------------------------------------------

class CardBacksScreen extends StatelessWidget {
  const CardBacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CollectionGridScreen(
      config: GridScreenConfig(
        category: 'cardBacks',
        headerIcon: Icons.style_rounded,
        headerTitle: 'CARD BACKS',
        headerSubtitle: 'Collect and equip unique card backs.',
        heroEyebrow: '',
        heroTitle: 'Card Backs',
        heroSubtitle:
            'Collect and equip unique card backs to express your style '
            'in every match.',
        heroArt: 'assets/art/hero_cardbacks.png',
        heroRarity: ZcRarity.epic,
        filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
        stripTitle: 'More stunning designs in the Store!',
        stripSubtitle: 'New card backs added every week.',
        showCollectionHeader: true,
        tabActive: 'Card Backs',
        showTabBar: true,
        artAspect: 0.7,
      ),
    );
  }
}

class SpecialCardsScreen extends StatelessWidget {
  const SpecialCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CollectionGridScreen(
      config: GridScreenConfig(
        category: 'specialCards',
        headerIcon: Icons.style_rounded,
        headerTitle: 'SPECIAL CARDS',
        headerSubtitle: 'Collect, own and use special cards in your games.',
        heroEyebrow: 'Your Highlight',
        heroTitle: 'Cosmic Ace',
        heroSubtitle: 'A cosmic glow that lights up the table when you '
            'play it.',
        heroArt: 'assets/art/hero_special.png',
        heroRarity: ZcRarity.epic,
        heroAction: 'Use in Game',
        heroDark: true,
        filters: ['All', 'Owned', 'Favorites', 'Epic', 'Legendary'],
        stripTitle: 'More special cards in the Store!',
        stripSubtitle: 'Collect unique cards and stand out in every game.',
        crossAxisCount: 5,
        artAspect: 0.72,
        showOwnedBadge: true,
        trailing: Icons.shopping_bag_outlined,
      ),
    );
  }
}

class AvatarsScreen extends StatelessWidget {
  const AvatarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CollectionGridScreen(
      config: GridScreenConfig(
        category: 'avatars',
        headerIcon: Icons.sentiment_satisfied_alt_rounded,
        headerTitle: 'AVATARS',
        headerSubtitle: 'Express yourself in every match!',
        heroEyebrow: 'Your Avatar',
        heroTitle: 'Cyber Zero',
        heroSubtitle: 'Locked in. Ready to win.',
        heroArt: 'assets/art/hero_avatars.png',
        heroRarity: ZcRarity.epic,
        heroDark: true,
        filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
        stripTitle: 'More avatars in the store!',
        stripSubtitle: 'New styles added every week.',
        crossAxisCount: 5,
        artAspect: 1.0,
        trailing: Icons.shopping_bag_outlined,
      ),
    );
  }
}

class EffectsScreen extends StatelessWidget {
  const EffectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CollectionGridScreen(
      config: GridScreenConfig(
        category: 'effects',
        headerIcon: Icons.auto_awesome_rounded,
        headerTitle: 'EFFECTS',
        headerSubtitle: 'Add some magic to your gameplay.',
        heroEyebrow: 'EQUIPPED EFFECT',
        heroTitle: 'Electric Spark',
        heroSubtitle: 'Electrify every move and light up the arena.',
        heroArt: 'assets/art/hero_effects.png',
        heroRarity: ZcRarity.epic,
        filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
        stripTitle: 'More effects in the Store!',
        stripSubtitle: 'Discover stunning effects to make your gameplay '
            'unique.',
        artAspect: 0.85,
        trailing: Icons.shopping_bag_outlined,
      ),
    );
  }
}

class StickersScreen extends StatelessWidget {
  const StickersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CollectionGridScreen(
      config: GridScreenConfig(
        category: 'stickers',
        headerIcon: Icons.emoji_emotions_rounded,
        headerTitle: 'STICKERS',
        headerSubtitle: 'Express more. Play your way!',
        heroEyebrow: 'EQUIPPED STICKER',
        heroTitle: 'GG Champ',
        heroSubtitle: 'Show your skills. Respect earned!',
        heroArt: 'assets/art/hero_stickers.png',
        heroRarity: ZcRarity.epic,
        filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
        stripTitle: 'More awesome stickers in the Store!',
        stripSubtitle: 'New stickers added every week.',
        artAspect: 1.0,
        trailing: Icons.shopping_bag_outlined,
      ),
    );
  }
}

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ThemesScreenImpl();
  }
}
