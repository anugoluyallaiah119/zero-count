import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/monetization/ad_reward_service.dart';
import '../../shared/monetization/iap_service.dart';
import '../../ui/zc_bottom_nav.dart';
import '../../ui/zc_theme.dart';
import '../player/profile_repository.dart';
import 'collection_data.dart';
import 'collection_grid_screen.dart';
import 'collection_widgets.dart';
import 'themes_screen.dart';

/// Store tab (light theme). Hosts 8 category tabs; sub-category content is
/// embedded so the tab bar and STORE header stay visible.
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key, this.initialTab});

  /// Optional deep-link into a specific category tab.
  final String? initialTab;

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  int _cat = 1; // Coins & Gems by default (matches mockup).
  int _selectedCoin = 2;
  int _selectedGem = 2;
  int _selectedCoinPack = 2;
  int _selectedGemPack = 2;

  static const _cats = [
    'Featured',
    'Coins & Gems',
    'Special Cards',
    'Card Backs',
    'Avatars',
    'Themes',
    'Effects',
    'Stickers',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab;
    if (initial != null) {
      final needle = initial.replaceAll('-', ' ').toLowerCase();
      final idx = _cats.indexWhere((c) => c.toLowerCase() == needle);
      if (idx >= 0) _cat = idx;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LcColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _StoreHeader(),
            const SizedBox(height: 8),
            _CategoryChips(
              cats: _cats,
              selected: _cat,
              onSelect: (i) => setState(() => _cat = i),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar:
          const ZcBottomNav(active: ZcNavTab.collection, dark: false),
    );
  }

  /// Category body — IndexedStack keeps scroll state per tab.
  Widget _body() {
    return IndexedStack(
      index: _cat,
      children: [
        _featuredTab(),
        _coinsGemsTab(),
        const CollectionGridScreen(
            config: _kSpecialCardsConfig, embedded: true),
        const CollectionGridScreen(
            config: _kCardBacksConfig, embedded: true),
        const CollectionGridScreen(config: _kAvatarsConfig, embedded: true),
        const ThemesScreenImpl(),
        const CollectionGridScreen(config: _kEffectsConfig, embedded: true),
        const CollectionGridScreen(config: _kStickersConfig, embedded: true),
      ],
    );
  }

  // ---------- FEATURED tab -------------------------------------------------

  Widget _featuredTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PowerYourGameBanner(),
            const SizedBox(height: 18),
            const Text(
              'Featured Categories',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: LcColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 2; i < _cats.length; i++)
                  _FeaturedTile(
                    label: _cats[i],
                    onTap: () => setState(() => _cat = i),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------- COINS & GEMS tab --------------------------------------------

  Widget _coinsGemsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _PowerYourGameBanner(),
          ),
          const _SectionTitle('Coins & Gems'),
          // Watch & Earn card.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _WatchAndEarnCard(),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CurrencyPanel(
                    title: 'COINS',
                    iconAsset: 'assets/art/coin.png',
                    accent: const Color(0xFFF59E0B),
                    accentSoft: const Color(0xFFFEF3C7),
                    art: 'assets/art/store_coins.png',
                    subtitle:
                        'Use coins to unlock items,\njoin events and more.',
                    quantities: const ['1,000', '5,000', '10,000', '25,000'],
                    packages: const [
                      _Pkg('10,000', '₹89', null, 'zc_coins_10000'),
                      _Pkg('25,000', '₹199', '10%', 'zc_coins_25000'),
                      _Pkg('60,000', '₹449', '20%', 'zc_coins_25000'),
                      _Pkg('150,000', '₹999', '30%', 'zc_coins_25000'),
                    ],
                    selectedQty: _selectedCoin,
                    selectedPkg: _selectedCoinPack,
                    onQty: (i) => setState(() => _selectedCoin = i),
                    onPkg: (i) => setState(() => _selectedCoinPack = i),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CurrencyPanel(
                    title: 'GEMS',
                    iconAsset: 'assets/art/gem.png',
                    accent: const Color(0xFF7C3AED),
                    accentSoft: const Color(0xFFEDE7FB),
                    art: 'assets/art/store_gems.png',
                    subtitle:
                        'Use gems for premium\nitems and exclusive\ncollections.',
                    quantities: const ['60', '250', '520', '1,100'],
                    packages: const [
                      _Pkg('60', '₹89', null, 'zc_gems_60'),
                      _Pkg('250', '₹199', '10%', 'zc_gems_250'),
                      _Pkg('520', '₹449', '20%', 'zc_gems_520'),
                      _Pkg('1,100', '₹999', '30%', 'zc_gems_1100'),
                    ],
                    selectedQty: _selectedGem,
                    selectedPkg: _selectedGemPack,
                    onQty: (i) => setState(() => _selectedGem = i),
                    onPkg: (i) => setState(() => _selectedGemPack = i),
                  ),
                ),
              ],
            ),
          ),
          const _SectionTitle('Special Offers'),
          const _SpecialOffersStrip(),
          const SizedBox(height: 14),
          const _TrustBadgesRow(),
        ],
      ),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================

class _StoreHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          _RoundIconBtn(
            icon: Icons.chevron_left_rounded,
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          const SizedBox(width: 10),
          const _StoreBadgeIcon(),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STORE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: LcColors.textDark,
                    letterSpacing: 0.5,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Enhance your experience. Stand out in every game.',
                  style: TextStyle(
                    fontSize: 10,
                    color: LcColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _CurrencyPill(asset: 'assets/art/coin.png', value: p?.coins ?? 0),
          const SizedBox(width: 6),
          _CurrencyPill(asset: 'assets/art/gem.png', value: p?.gems ?? 0),
          const SizedBox(width: 6),
          const _GiftBellButton(badge: 2),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LcColors.chipBorder, width: 1.2),
          ),
          child: Icon(icon, color: LcColors.textDark, size: 22),
        ),
      ),
    );
  }
}

class _StoreBadgeIcon extends StatelessWidget {
  const _StoreBadgeIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B46E8), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40A855F7),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.shopping_bag_rounded,
          color: Colors.white, size: 22),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.asset, required this.value});
  final String asset;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 3, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LcColors.chipBorder, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset,
              width: 16,
              height: 16,
              errorBuilder: (_, __, ___) => const Icon(
                    Icons.monetization_on_rounded,
                    size: 16,
                    color: Color(0xFFF59E0B),
                  )),
          const SizedBox(width: 3),
          Text(
            _fmt(value),
            style: const TextStyle(
              color: LcColors.textDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 3),
          Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.add_rounded, color: Colors.white, size: 11),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _GiftBellButton extends StatelessWidget {
  const _GiftBellButton({required this.badge});
  final int badge;
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LcColors.chipBorder, width: 1.2),
          ),
          child: const Icon(Icons.card_giftcard_rounded,
              color: LcColors.textDark, size: 22),
        ),
        if (badge > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$badge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// CATEGORY CHIPS
// =============================================================================

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.cats,
    required this.selected,
    required this.onSelect,
  });
  final List<String> cats;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _icons = [
    Icons.star_rounded,
    Icons.monetization_on_rounded,
    Icons.style_rounded,
    Icons.credit_card_rounded,
    Icons.sentiment_satisfied_alt_rounded,
    Icons.image_rounded,
    Icons.auto_awesome_rounded,
    Icons.emoji_emotions_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == selected;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: active ? LcColors.purple : LcColors.chipBorder,
                    width: active ? 1.6 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icons[i],
                        size: 15,
                        color:
                            active ? LcColors.purple : LcColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      cats[i],
                      style: TextStyle(
                        color:
                            active ? LcColors.purple : LcColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// HERO "POWER YOUR GAME"
// =============================================================================

class _PowerYourGameBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7EEFF), Color(0xFFEFE3FE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0D3F5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: LcColors.purple,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Power Your\nGame',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: LcColors.textDark,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Coins for matches.\nGems for premium rewards.',
                  style: TextStyle(
                    color: LcColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniFeatureChip(
                        icon: 'assets/art/coin.png',
                        title: 'Play More',
                        subtitle: 'Win Bigger',
                        accent: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _MiniFeatureChip(
                        icon: 'assets/art/gem.png',
                        title: 'Unlock More',
                        subtitle: 'Stand Out',
                        accent: LcColors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Image.asset(
              'assets/art/store_pack_purple.png',
              height: 130,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.card_giftcard_rounded,
                size: 100,
                color: LcColors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeatureChip extends StatelessWidget {
  const _MiniFeatureChip({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });
  final String icon;
  final String title;
  final String subtitle;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4DFF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Image.asset(icon,
                width: 14,
                height: 14,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.star_rounded, size: 12, color: accent)),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: LcColors.textDark,
                        height: 1.1)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 9,
                        color: LcColors.textMuted,
                        fontWeight: FontWeight.w600,
                        height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION TITLE
// =============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: LcColors.textDark)),
          const Spacer(),
          const Text('View All',
              style: TextStyle(
                  color: LcColors.textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const Icon(Icons.chevron_right_rounded,
              color: LcColors.textDark, size: 18),
        ],
      ),
    );
  }
}

// =============================================================================
// CURRENCY PANEL (COINS / GEMS)
// =============================================================================

class _Pkg {
  const _Pkg(this.qty, this.price, this.extra, this.iapId);
  final String qty;
  final String price;
  final String? extra;
  final String iapId; // IAP product id
}

class _CurrencyPanel extends StatelessWidget {
  const _CurrencyPanel({
    required this.title,
    required this.iconAsset,
    required this.accent,
    required this.accentSoft,
    required this.art,
    required this.subtitle,
    required this.quantities,
    required this.packages,
    required this.selectedQty,
    required this.selectedPkg,
    required this.onQty,
    required this.onPkg,
  });
  final String title;
  final String iconAsset;
  final Color accent;
  final Color accentSoft;
  final String art;
  final String subtitle;
  final List<String> quantities;
  final List<_Pkg> packages;
  final int selectedQty;
  final int selectedPkg;
  final ValueChanged<int> onQty;
  final ValueChanged<int> onPkg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LcColors.chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 72,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(iconAsset,
                            width: 16,
                            height: 16,
                            errorBuilder: (_, __, ___) => Icon(
                                  Icons.monetization_on_rounded,
                                  size: 16,
                                  color: accent,
                                )),
                        const SizedBox(width: 5),
                        Text(title,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: 0.3)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: LcColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Image.asset(
                    art,
                    width: 78,
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      title == 'COINS'
                          ? Icons.monetization_on_rounded
                          : Icons.diamond_rounded,
                      color: accent,
                      size: 44,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quantities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, i) {
                final active = i == selectedQty;
                return GestureDetector(
                  onTap: () => onQty(i),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? accent : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? accent : LcColors.chipBorder,
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      quantities[i],
                      style: TextStyle(
                        color: active ? Colors.white : LcColors.textDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < packages.length; i++) ...[
            _PackageRow(
              iconAsset: iconAsset,
              accent: accent,
              accentSoft: accentSoft,
              pkg: packages[i],
              selected: i == selectedPkg,
              onTap: () => onPkg(i),
            ),
            if (i < packages.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.iconAsset,
    required this.accent,
    required this.accentSoft,
    required this.pkg,
    required this.selected,
    required this.onTap,
  });
  final String iconAsset;
  final Color accent;
  final Color accentSoft;
  final _Pkg pkg;
  final bool selected;
  final VoidCallback onTap;

  Color _extraColor(String? e) {
    if (e == null) return const Color(0xFFF97316);
    if (e.startsWith('30')) return const Color(0xFFF97316);
    if (e.startsWith('20')) return const Color(0xFFEF4444);
    return const Color(0xFF7C3AED);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: selected ? accentSoft : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent : const Color(0xFFE9E4F5),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Image.asset(iconAsset,
                  width: 18,
                  height: 18,
                  errorBuilder: (_, __, ___) => Icon(
                        Icons.monetization_on_rounded,
                        size: 18,
                        color: accent,
                      )),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pkg.qty,
                  style: const TextStyle(
                    color: LcColors.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IapBuyButton(
                productId: pkg.iapId,
                fallbackPrice: pkg.price,
              ),
              if (pkg.extra != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: _extraColor(pkg.extra),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pkg.extra!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              height: 1)),
                      const Text('EXTRA',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              height: 1.1)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SPECIAL OFFERS
// =============================================================================

class _SpecialOffersStrip extends StatelessWidget {
  const _SpecialOffersStrip();
  @override
  Widget build(BuildContext context) {
    const offers = [
      _Offer('-30%', '2d 14h', 'assets/art/store_pack_purple.png',
          'Cosmic Pack'),
      _Offer(
          '-25%', '2d 14h', 'assets/art/store_pack_royal.png', 'Royal Set'),
      _Offer('-20%', '1d 14h', 'assets/art/store_pack_ice.png',
          'Ice Collection'),
      _Offer('-30%', '2d 14h', 'assets/art/store_sticker_bundle.png',
          'Sticker Bundle'),
    ];
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _OfferCard(offer: offers[i]),
      ),
    );
  }
}

class _Offer {
  const _Offer(this.pct, this.time, this.art, this.title);
  final String pct;
  final String time;
  final String art;
  final String title;
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});
  final _Offer offer;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LcColors.chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(offer.pct,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              const Icon(Icons.schedule_rounded,
                  size: 10, color: LcColors.textMuted),
              const SizedBox(width: 2),
              Text(offer.time,
                  style: const TextStyle(
                      color: LcColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: Image.asset(
                offer.art,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.card_giftcard_rounded,
                    size: 40,
                    color: LcColors.purple),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Center(
            child: Text(offer.title,
                style: const TextStyle(
                    color: LcColors.textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const FittedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded,
                      size: 11, color: LcColors.textMuted),
                  SizedBox(width: 4),
                  Text('Price Locked',
                      style: TextStyle(
                          color: LcColors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TRUST BADGES ROW
// =============================================================================

class _TrustBadgesRow extends StatelessWidget {
  const _TrustBadgesRow();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LcColors.chipBorder),
      ),
      child: const Row(
        children: [
          Expanded(
              child: _TrustItem(
            icon: Icons.monetization_on_rounded,
            iconColor: Color(0xFFF59E0B),
            title: 'More Coins',
            subtitle: 'Play more matches\n& win big',
          )),
          Expanded(
              child: _TrustItem(
            icon: Icons.diamond_rounded,
            iconColor: LcColors.purple,
            title: 'More Gems',
            subtitle: 'Unlock themes,\neffects & more',
          )),
          Expanded(
              child: _TrustItem(
            icon: Icons.shield_rounded,
            iconColor: Color(0xFF10B981),
            title: 'Secure Payment',
            subtitle: '100% secure\ntransactions',
          )),
          Expanded(
              child: _TrustItem(
            icon: Icons.workspace_premium_rounded,
            iconColor: Color(0xFFF59E0B),
            title: 'Best Value',
            subtitle: 'Extra bonuses on\nevery purchase',
          )),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: LcColors.textDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  height: 1.1)),
          const SizedBox(height: 3),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: LcColors.textMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25)),
        ],
      ),
    );
  }
}

// =============================================================================
// FEATURED TILE
// =============================================================================

class _FeaturedTile extends StatelessWidget {
  const _FeaturedTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: (MediaQuery.of(context).size.width - 40) / 2,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LcColors.chipBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: LcColors.purple),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      color: LcColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-category grid configs (mirror the wrappers in collection_grid_screen.dart)
// =============================================================================

const _kCardBacksConfig = GridScreenConfig(
  category: 'cardBacks',
  headerIcon: Icons.style_rounded,
  headerTitle: 'CARD BACKS',
  headerSubtitle: 'Collect and equip unique card backs.',
  heroEyebrow: '',
  heroTitle: 'Card Backs',
  heroSubtitle:
      'Collect and equip unique card backs to express your style in every match.',
  heroArt: 'assets/art/hero_cardbacks.png',
  heroRarity: ZcRarity.epic,
  filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
  stripTitle: 'More stunning designs in the Store!',
  stripSubtitle: 'New card backs added every week.',
  artAspect: 0.7,
);

const _kSpecialCardsConfig = GridScreenConfig(
  category: 'specialCards',
  headerIcon: Icons.style_rounded,
  headerTitle: 'SPECIAL CARDS',
  headerSubtitle: 'Collect, own and use special cards in your games.',
  heroEyebrow: 'Your Highlight',
  heroTitle: 'Cosmic Ace',
  heroSubtitle: 'A cosmic glow that lights up the table when you play it.',
  heroArt: 'assets/art/hero_special.png',
  heroRarity: ZcRarity.epic,
  heroAction: 'Use in Game',
  filters: ['All', 'Owned', 'Favorites', 'Epic', 'Legendary'],
  stripTitle: 'More special cards in the Store!',
  stripSubtitle: 'Collect unique cards and stand out in every game.',
  crossAxisCount: 5,
  artAspect: 0.72,
  showOwnedBadge: true,
);

const _kAvatarsConfig = GridScreenConfig(
  category: 'avatars',
  headerIcon: Icons.person_rounded,
  headerTitle: 'AVATARS',
  headerSubtitle: 'Pick a look that speaks for you.',
  heroEyebrow: 'Featured',
  heroTitle: 'Mystic Jester',
  heroSubtitle: 'A mysterious face for a mysterious mind.',
  heroArt: 'assets/art/store_avatar_jester.png',
  heroRarity: ZcRarity.epic,
  filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
  stripTitle: 'More avatars in the Store!',
  stripSubtitle: 'Express yourself with fresh looks.',
);

const _kEffectsConfig = GridScreenConfig(
  category: 'effects',
  headerIcon: Icons.auto_awesome_rounded,
  headerTitle: 'EFFECTS',
  headerSubtitle: 'Add flair to your table.',
  heroEyebrow: 'Trending',
  heroTitle: 'Electric Spark',
  heroSubtitle: 'A spark of electricity every big move.',
  heroArt: 'assets/art/ef_rainbow.png',
  heroRarity: ZcRarity.epic,
  filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
  stripTitle: 'More effects in the Store!',
  stripSubtitle: 'Light up your table.',
);

const _kStickersConfig = GridScreenConfig(
  category: 'stickers',
  headerIcon: Icons.emoji_emotions_rounded,
  headerTitle: 'STICKERS',
  headerSubtitle: 'Chat with style.',
  heroEyebrow: 'Fan Favorite',
  heroTitle: 'GG Champ',
  heroSubtitle: 'Show your team spirit.',
  heroArt: 'assets/art/st_gg.png',
  heroRarity: ZcRarity.rare,
  filters: ['All', 'Owned', 'Favorites', 'Rare', 'Epic', 'Legendary'],
  stripTitle: 'More stickers in the Store!',
  stripSubtitle: 'React with flair.',
);

// =============================================================================
// WATCH & EARN CARD
// =============================================================================

class _WatchAndEarnCard extends ConsumerStatefulWidget {
  const _WatchAndEarnCard();

  @override
  ConsumerState<_WatchAndEarnCard> createState() => _WatchAndEarnCardState();
}

class _WatchAndEarnCardState extends ConsumerState<_WatchAndEarnCard> {
  bool _watching = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(adStatusProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0B3D), Color(0xFF2A0E5C)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0x66A855F7), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0x44FDE047)),
            ),
            child: const Icon(Icons.play_circle_filled_rounded,
                color: Color(0xFFFDE047), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Watch & Earn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                statusAsync.when(
                  loading: () => const Text('Loading…',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 11)),
                  error: (_, __) => const Text(
                      'Tap to earn 50 coins',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 11)),
                  data: (s) => Text(
                    s.canWatch
                        ? '+50 coins  •  ${s.remaining}/${s.dailyCap} remaining today'
                        : 'Come back tomorrow — ${s.dailyCap} ads/day',
                    style: TextStyle(
                      color: s.canWatch
                          ? const Color(0xFFFDE047)
                          : Colors.white38,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          statusAsync.when(
            loading: () => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => ElevatedButton(
              onPressed: (!s.canWatch || _watching)
                  ? null
                  : () => _watch(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDE047),
                disabledBackgroundColor: const Color(0x33FFFFFF),
                foregroundColor: const Color(0xFF1A0B3D),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
              ),
              child: _watching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A0B3D)))
                  : Text(
                      s.canWatch ? 'WATCH' : 'DONE',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _watch(BuildContext context) async {
    setState(() => _watching = true);
    try {
      final result =
          await ref.read(adRewardServiceProvider).watchAndEarn();
      if (!mounted) return;
      if (result != null) {
        ref.invalidate(adStatusProvider);
        ref.invalidate(profileProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '+${result.coins} coins! Balance: ${result.balance}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF22C55E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }
}

// =============================================================================
// IAP BUY BUTTON — replaces the _PackageRow price pill with real purchase
// =============================================================================

class IapBuyButton extends ConsumerStatefulWidget {
  const IapBuyButton({super.key, required this.productId, required this.fallbackPrice});
  final String productId;
  final String fallbackPrice;

  @override
  ConsumerState<IapBuyButton> createState() => _IapBuyButtonState();
}

class _IapBuyButtonState extends ConsumerState<IapBuyButton> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Listen for purchase results targeting this product.
    final iap = ref.read(iapServiceProvider);
    iap.results.listen((r) {
      if (!mounted) return;
      if (r.state == IapPurchaseState.purchasing) {
        setState(() => _loading = true);
        return;
      }
      setState(() => _loading = false);
      if (r.state == IapPurchaseState.success) {
        ref.invalidate(profileProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.coins != null
              ? '+${r.coins} coins!'
              : '+${r.gems} gems!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF22C55E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      } else if (r.state == IapPurchaseState.error ||
          r.state == IapPurchaseState.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.message ?? 'Purchase failed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ZcColors.errorRed,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final iap = ref.watch(iapServiceProvider);
    final product = iap.products[widget.productId];
    final priceLabel = product?.price ?? widget.fallbackPrice;

    return GestureDetector(
      onTap: _loading ? null : () => iap.buy(widget.productId),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _loading
              ? const Color(0x22FFFFFF)
              : const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(7),
        ),
        child: _loading
            ? const SizedBox(
                width: 28,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white))
            : Text(
                priceLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}
