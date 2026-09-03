import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_bottom_nav.dart';
import '../../ui/zc_theme.dart';
import 'collection_data.dart';
import 'collection_widgets.dart';

/// Collection → Store (light theme mockup). Purchases are placeholders
/// ("Price Locked") until the store backend ships post-V2.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _cat = 0;
  final _scroll = ScrollController();
  final _currencyKey = GlobalKey();

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

  static const _routes = {
    'Special Cards': '/collection/special-cards',
    'Card Backs': '/collection/card-backs',
    'Avatars': '/collection/avatars',
    'Themes': '/collection/themes',
    'Effects': '/collection/effects',
    'Stickers': '/collection/stickers',
  };

  void _onCategory(int i) {
    final label = _cats[i];
    final route = _routes[label];
    if (route != null) {
      context.push(route);
      return;
    }
    if (label == 'Coins & Gems') {
      setState(() => _cat = i);
      final ctx = _currencyKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300), alignment: 0.05);
      }
      return;
    }
    setState(() => _cat = i);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LcColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const CollectionHeader(
              icon: Icons.shopping_cart_rounded,
              title: 'STORE',
              subtitle: 'Enhance your experience. Stand out in every game.',
              trailing: Icons.shopping_bag_outlined,
            ),
            const SizedBox(height: 10),
            _categoryChips(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _featuredBanner(),
                    _sectionTitle('Coins & Gems', key: _currencyKey),
                    _currencyPanels(),
                    _sectionTitle('Special Offers'),
                    _specialOffers(),
                    _sectionTitle('Popular Items'),
                    _popularItems(),
                    const SizedBox(height: 14),
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

  Widget _categoryChips() {
    const icons = [
      Icons.star_rounded,
      Icons.monetization_on_outlined,
      Icons.style_outlined,
      Icons.credit_card_rounded,
      Icons.sentiment_satisfied_alt_rounded,
      Icons.image_outlined,
      Icons.auto_awesome_rounded,
      Icons.emoji_emotions_outlined,
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (var i = 0; i < _cats.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => _onCategory(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: i == _cat ? LcColors.purple : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: i == _cat
                            ? LcColors.purple
                            : LcColors.chipBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(icons[i],
                          size: 14,
                          color: i == _cat
                              ? Colors.white
                              : LcColors.textMuted),
                      const SizedBox(width: 5),
                      Text(_cats[i],
                          style: TextStyle(
                              color: i == _cat
                                  ? Colors.white
                                  : LcColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _featuredBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LcColors.chipBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/art/th_galaxy.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Color(0x00FFFFFF)],
                  stops: [0.45, 0.85],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEW THEME',
                    style: ZcText.body(9.5).copyWith(
                        color: LcColors.purple, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('Cosmic Drift',
                        style: ZcText.heading(19)
                            .copyWith(color: LcColors.textDark)),
                    const SizedBox(width: 8),
                    const RarityChip(rarity: _Rarity.epic),
                  ],
                ),
                const SizedBox(height: 5),
                Text('A vast space to focus,\nthink and win.',
                    style: ZcText.body(11.5)
                        .copyWith(color: LcColors.textMuted)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF8B46E8), Color(0xFF5B21B6)]),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Explore',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        width: i == 0 ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? LcColors.purple
                              : const Color(0xFFCFC8E4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 8),
      child: Row(
        children: [
          Text(t,
              style:
                  ZcText.heading(15).copyWith(color: LcColors.textDark)),
          const Spacer(),
          Text('View All',
              style: ZcText.body(11.5).copyWith(
                  color: LcColors.purple, fontWeight: FontWeight.w800)),
          const Icon(Icons.chevron_right_rounded,
              color: LcColors.purple, size: 16),
        ],
      ),
    );
  }

  Widget _currencyPanels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: _currencyPanel(
              icon: 'assets/art/coin.png',
              title: 'COINS',
              desc: 'Use coins to unlock items, join events and more.',
              art: 'assets/art/store_coins.png',
              amounts: const ['1,000', '5,000', '10,000', '25,000'],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _currencyPanel(
              icon: 'assets/art/gem.png',
              title: 'GEMS',
              desc: 'Use gems for premium items and exclusive collections.',
              art: 'assets/art/store_gems.png',
              amounts: const ['60', '250', '520', '1,100'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyPanel({
    required String icon,
    required String title,
    required String desc,
    required String art,
    required List<String> amounts,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LcColors.chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(icon, width: 16, height: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(title,
                    style: ZcText.heading(12)
                        .copyWith(color: LcColors.textDark)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc,
              style:
                  ZcText.body(9.5).copyWith(color: LcColors.textMuted),
              maxLines: 2),
          const SizedBox(height: 8),
          Center(child: Image.asset(art, height: 62, fit: BoxFit.contain)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final a in amounts)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: LcColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LcColors.chipBorder),
                  ),
                  child: Text(a,
                      style: const TextStyle(
                          color: LcColors.textDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const _PriceLockedButton(),
        ],
      ),
    );
  }

  Widget _specialOffers() {
    const offers = [
      ('-30%', '2d 14h', 'assets/art/store_pack_purple.png', 'Cosmic Pack'),
      ('-25%', '2d 14h', 'assets/art/store_pack_royal.png', 'Royal Set'),
      ('-20%', '1d 14h', 'assets/art/store_pack_ice.png', 'Ice Collection'),
      ('-30%', '2d 14h', 'assets/art/store_sticker_bundle.png',
          'Sticker Bundle'),
    ];
    return SizedBox(
      height: 205,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final o in offers)
            Container(
              width: 128,
              margin: const EdgeInsets.only(right: 9),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LcColors.chipBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ZcColors.errorRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(o.$1,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 22),
                      FittedBox(
                        child: Row(children: [
                          const Icon(Icons.schedule_rounded,
                              size: 10, color: LcColors.textMuted),
                          const SizedBox(width: 2),
                          Text(o.$2,
                              style: ZcText.body(8.5)
                                  .copyWith(color: LcColors.textMuted)),
                        ]),
                      ),
                    ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        o.$3,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.card_giftcard_rounded,
                          color: LcColors.purple,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    child: Text(o.$4,
                        style: ZcText.body(11).copyWith(
                            color: LcColors.textDark,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 6),
                  const _PriceLockedButton(compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _popularItems() {
    const items = [
      ('Epic', 'assets/art/sp_zero_classic.png', 'Neon Pulse', 'Card Back'),
      ('Epic', 'assets/art/store_avatar_jester.png', 'Mystic Jester',
          'Avatar'),
      ('Legendary', 'assets/art/store_ace_inferno.png', 'Inferno Ace',
          'Special Card'),
      ('Epic', 'assets/art/ef_rainbow.png', 'Electric Spark', 'Effect'),
      ('Rare', 'assets/art/st_gg.png', 'GG Champ', 'Sticker'),
    ];
    return SizedBox(
      height: 205,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final it in items)
            Container(
              width: 118,
              margin: const EdgeInsets.only(right: 9),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LcColors.chipBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Row(
                    children: [
                      _miniRarity(it.$1),
                      const SizedBox(width: 20),
                      const Icon(Icons.favorite_border_rounded,
                          size: 14, color: LcColors.textMuted),
                    ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        it.$2,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.style_rounded,
                          color: LcColors.purple,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(it.$3,
                      style: ZcText.body(10.5).copyWith(
                          color: LcColors.textDark,
                          fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(it.$4,
                      style: ZcText.body(9)
                          .copyWith(color: LcColors.textMuted)),
                  const SizedBox(height: 5),
                  const _PriceLockedButton(compact: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniRarity(String label) {
    final r = switch (label) {
      'Rare' => _Rarity.rare,
      'Legendary' => _Rarity.legendary,
      _ => _Rarity.epic,
    };
    final (fg, bg) = rarityColors(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 8.5, fontWeight: FontWeight.w800)),
    );
  }
}

// Alias so this file can reference the rarity enum concisely.
typedef _Rarity = ZcRarity;

class _PriceLockedButton extends StatelessWidget {
  const _PriceLockedButton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7FB),
        borderRadius: BorderRadius.circular(9),
      ),
      child: FittedBox(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_open_rounded,
                size: 11, color: LcColors.textMuted),
            const SizedBox(width: 5),
            Text('Price Locked',
                style: TextStyle(
                    color: LcColors.textMuted,
                    fontSize: compact ? 9.5 : 10.5,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
