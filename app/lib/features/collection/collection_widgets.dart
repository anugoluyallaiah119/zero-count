import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_card_backs.dart';
import '../../ui/zc_cosmetics.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import '../player/profile_repository.dart';
import 'collection_data.dart';
import 'shop_repository.dart';

/// Light-theme tokens from the Collection mockups.
class LcColors {
  LcColors._();
  static const bg = Color(0xFFF4F1FB);
  static const card = Colors.white;
  static const textDark = Color(0xFF1A1230);
  static const textMuted = Color(0xFF7A7291);
  static const purple = Color(0xFF7C3AED);
  static const purpleDark = Color(0xFF5B21B6);
  static const chipBorder = Color(0xFFE4DFF2);
  static const rareBlue = Color(0xFF3B82F6);
  static const rareBg = Color(0xFFE8F0FE);
  static const epicPurple = Color(0xFF8B46E8);
  static const epicBg = Color(0xFFF1E9FD);
  static const legendaryOrange = Color(0xFFD97706);
  static const legendaryBg = Color(0xFFFCF0DA);
}

(Color, Color) rarityColors(ZcRarity r) => switch (r) {
      ZcRarity.rare => (LcColors.rareBlue, LcColors.rareBg),
      ZcRarity.epic => (LcColors.epicPurple, LcColors.epicBg),
      ZcRarity.legendary => (LcColors.legendaryOrange, LcColors.legendaryBg),
    };

/// Small rarity chip (Rare / Epic / Legendary).
class RarityChip extends StatelessWidget {
  const RarityChip({super.key, required this.rarity});

  final ZcRarity rarity;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = rarityColors(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: FittedBox(
        child: Text(rarity.label,
            style: TextStyle(
                color: fg, fontSize: 10.5, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Light header for Collection screens: back square, purple icon badge +
/// title + subtitle, coin/gem pills, trailing square icon.
class CollectionHeader extends ConsumerWidget {
  const CollectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing = Icons.lock_rounded,
    this.showBack = true,
    this.dark = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final bool showBack;

  /// Dark variant for the Avatars / Special Cards mockups.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).valueOrNull;
    final titleColor = dark ? Colors.white : LcColors.textDark;
    final subColor = dark ? ZcColors.textSecondary : LcColors.textMuted;
    final squareColor = dark ? const Color(0x990D0330) : Colors.white;
    final squareBorder =
        dark ? const Color(0x40FFFFFF) : LcColors.chipBorder;
    Widget square({required Widget child, VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: squareColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: squareBorder),
          ),
          child: child,
        ),
      );
    }

    Widget pill(String asset, String value) {
      if (!dark) return lightCurrencyPill(asset, value);
      return Container(
        padding: const EdgeInsets.fromLTRB(5, 3, 4, 3),
        decoration: BoxDecoration(
          color: const Color(0x990D0330),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          children: [
            Image.asset(asset, width: 16, height: 16),
            const SizedBox(width: 3),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 3),
            const CircleAvatar(
              radius: 7,
              backgroundColor: ZcColors.onlineGreen,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 11),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          if (showBack) ...[
            square(
              child: Icon(Icons.chevron_left_rounded,
                  color: titleColor, size: 24),
              onTap: () {
                if (context.canPop()) context.pop();
              },
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B46E8), Color(0xFF5B21B6)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: ZcText.heading(15)
                          .copyWith(color: titleColor)),
                ),
                Text(subtitle,
                    style: ZcText.body(10.5)
                        .copyWith(color: subColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          pill('assets/art/coin.png', '${p?.coins ?? 0}'),
          const SizedBox(width: 6),
          pill('assets/art/gem.png', '${p?.gems ?? 0}'),
          const SizedBox(width: 6),
          square(
              child: Icon(trailing,
                  color: dark ? Colors.white : LcColors.textMuted,
                  size: 19)),
        ],
      ),
    );
  }

}

Widget lightCurrencyPill(String asset, String value) {
  return Container(
    padding: const EdgeInsets.fromLTRB(5, 4, 4, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: LcColors.chipBorder),
    ),
    child: Row(
      children: [
        Image.asset(asset, width: 16, height: 16),
        const SizedBox(width: 3),
        Text(value,
            style: const TextStyle(
                color: LcColors.textDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 3),
        const CircleAvatar(
          radius: 7,
          backgroundColor: LcColors.purple,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 11),
        ),
      ],
    ),
  );
}

Widget _lightSquare({required Widget child, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LcColors.chipBorder),
      ),
      child: child,
    ),
  );
}

/// Filter chip row: All / Owned / Favorites / rarity chips + Sort button.
class CollectionFilters extends StatelessWidget {
  const CollectionFilters({
    super.key,
    required this.filters,
    required this.active,
    required this.onChanged,
    this.sortLabel = 'Sort',
  });

  final List<String> filters;
  final int active;
  final ValueChanged<int> onChanged;
  final String sortLabel;

  static const _icons = <String, IconData>{
    'All': Icons.grid_view_rounded,
    'Owned': Icons.check_circle_outline_rounded,
    'Favorites': Icons.favorite_border_rounded,
    'Premium': Icons.workspace_premium_rounded,
    'Rare': Icons.diamond_outlined,
    'Epic': Icons.workspace_premium_outlined,
    'Legendary': Icons.star_border_rounded,
    'Nature': Icons.eco_outlined,
    'City': Icons.location_city_rounded,
    'Abstract': Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (var i = 0; i < filters.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        i == active ? LcColors.purple : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: i == active
                            ? LcColors.purple
                            : LcColors.chipBorder),
                  ),
                  child: Row(
                    children: [
                      if (_icons[filters[i]] != null && i != active) ...[
                        Icon(_icons[filters[i]],
                            size: 14, color: LcColors.textMuted),
                        const SizedBox(width: 5),
                      ],
                      Text(filters[i],
                          style: TextStyle(
                              color: i == active
                                  ? Colors.white
                                  : LcColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: LcColors.chipBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_vert_rounded,
                    size: 14, color: LcColors.textMuted),
                const SizedBox(width: 5),
                Text(sortLabel,
                    style: const TextStyle(
                        color: LcColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 14, color: LcColors.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One grid cell: art, name, rarity chip, equipped check / heart / lock.
class CollectionGridCard extends ConsumerWidget {
  const CollectionGridCard({
    super.key,
    required this.category,
    required this.item,
    this.artAspect = 0.82,
    this.showOwnedBadge = false,
  });

  final String category;
  final CollectionItem item;

  /// art width/height ratio inside the card (cards are tall, stickers ~1).
  final double artAspect;
  final bool showOwnedBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(collectionProvider.notifier);
    // Card backs use code-drawn painters; avatars use ZcAvatars; all others fallback.
    final isCardBack = category == 'cardBacks';
    final isAvatar = category == 'avatars';
    return GestureDetector(
      onTap: () async {
        if (!item.owned) {
          // Attempt real purchase via the shop API.
          try {
            await ref.read(shopCatalogProvider.notifier).buy(item.id);
            ref.read(collectionProvider.notifier).markOwned(category, item.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${item.name} purchased!'),
                backgroundColor: LcColors.purple,
              ));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(e.toString()),
                backgroundColor: Colors.red,
              ));
            }
          }
        } else {
          ctrl.equip(category, item.id);
          if (isCardBack || category == 'themes' || category == 'avatars' ||
              category == 'specialCards' || category == 'effects' ||
              category == 'stickers') {
            // Persist equip to server for all cosmetic categories.
            try {
              await ref.read(shopRepositoryProvider).equip(item.id);
            } catch (_) {}
            ref.invalidate(profileProvider);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: LcColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: item.equipped ? LcColors.purple : LcColors.chipBorder,
              width: item.equipped ? 2.0 : 1),
          boxShadow: item.equipped
              ? [BoxShadow(color: LcColors.purple.withValues(alpha: 0.18), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Avatar uses circular clip; all others use rounded rect.
                isAvatar
                    ? AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, box) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: item.equipped
                                    ? LcColors.purple
                                    : const Color(0xFFE4DFF2),
                                width: item.equipped ? 2.5 : 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: ZcAvatars.forId(item.asset, box.maxWidth),
                            ),
                          ),
                        ),
                      )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: AspectRatio(
                    aspectRatio: artAspect,
                    child: isCardBack
                        ? LayoutBuilder(
                            builder: (context, box) => ZcCardBackWidget(
                              backId: item.asset,
                              width: box.maxWidth,
                            ),
                          )
                        : const SizedBox.shrink()
                            : Image.asset(
                                item.asset,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF2E1065),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.style_rounded,
                                            color: Color(0xFFFDE047), size: 22),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
                // Top-right badge: checkmark if equipped, heart if owned, lock if not owned
                if (!item.equipped)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => ctrl.toggleFavorite(category, item.id),
                      child: item.owned
                          ? Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0x99000000),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: item.favorite
                                    ? Colors.pink
                                    : Colors.white,
                                size: 13,
                              ),
                            )
                          : Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0x99000000),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_rounded,
                                  color: Colors.white, size: 13),
                            ),
                    ),
                  ),
                // Checkmark in top-left corner for equipped item (like mockup)
                if (item.equipped)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: LcColors.purple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (showOwnedBadge && item.owned)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: const FittedBox(
                  child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: LcColors.purple, size: 12),
                    SizedBox(width: 3),
                    Text('Owned',
                        style: TextStyle(
                            color: LcColors.textDark,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600)),
                  ],
                  ),
                ),
              ),
            Text(item.name,
                style: ZcText.body(11).copyWith(
                    color: LcColors.textDark, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            if (item.equipped)
              // Green Equipped chip — matches mockup
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 10),
                    SizedBox(width: 3),
                    Text('Equipped',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              )
            else if (!item.owned && item.price != null)
              // Price pill with coin icon — matches mockup
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/art/coin.png',
                      width: 12,
                      height: 12,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.monetization_on_rounded,
                          size: 12,
                          color: Color(0xFFF59E0B))),
                  const SizedBox(width: 3),
                  Text(
                    item.price == 0
                        ? 'FREE'
                        : '${(item.price! / 100).round()}',
                    style: const TextStyle(
                        color: LcColors.textDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              )
            else
              RarityChip(rarity: item.rarity),
          ],
        ),
      ),
    );
  }
}

/// "More X in the Store!" purple promo strip with Visit Store button.
class VisitStoreStrip extends StatelessWidget {
  const VisitStoreStrip({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B46E8), Color(0xFF5B21B6)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ZcText.body(12).copyWith(
                        color: LcColors.purple, fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: ZcText.body(10)
                        .copyWith(color: LcColors.textMuted),
                    maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/collection'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF8B46E8), Color(0xFF5B21B6)]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(
                children: [
                  Text('Visit Store',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profile-style header on light background (Card Backs mockup):
/// avatar + greeting + level bar, centered logo, light currency pills, bell.
class EventsHeaderLight extends ConsumerWidget {
  const EventsHeaderLight({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).valueOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: LcColors.purple,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: LcColors.bg,
              backgroundImage: (p?.avatar.isNotEmpty ?? false)
                  ? AssetImage(avatarAsset(p!.avatar))
                  : null,
              child: (p?.avatar.isEmpty ?? true)
                  ? const Icon(Icons.person_rounded,
                      color: LcColors.textMuted, size: 22)
                  : null,
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, ${p?.displayName ?? 'Player'}!',
                  style: ZcText.heading(13.5)
                      .copyWith(color: LcColors.textDark),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              FittedBox(
                child: Row(
                children: [
                  Text('Level ${p?.level ?? 1}',
                      style: ZcText.body(10.5)
                          .copyWith(color: LcColors.purple)),
                  const SizedBox(width: 6),
                  Container(
                    width: 52,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DAF0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (p?.levelProgress ?? 0).clamp(0.05, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFF8B46E8),
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
          Image.asset('assets/art/logo.png', height: 30),
          const Spacer(),
          lightCurrencyPill('assets/art/coin.png', '${p?.coins ?? 0}'),
          const SizedBox(width: 5),
          lightCurrencyPill('assets/art/gem.png', '${p?.gems ?? 0}'),
          const SizedBox(width: 6),
          _lightSquare(
              child: const Icon(Icons.notifications_rounded,
                  color: LcColors.textMuted, size: 18)),
        ],
      ),
    );
  }
}

/// Collection tab bar used on the Card Backs mockup:
/// Store · Card Backs · Avatars · Themes · Effects · Stickers.
class CollectionTabBar extends StatelessWidget {
  const CollectionTabBar({super.key, required this.active});

  final String active;

  static const _tabs = {
    'Store': '/collection',
    'Card Backs': '/collection/card-backs',
    'Avatars': '/collection/avatars',
    'Themes': '/collection/themes',
    'Effects': '/collection/effects',
    'Stickers': '/collection/stickers',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final e in _tabs.entries)
            GestureDetector(
              onTap: () {
                if (e.key != active) context.go(e.value);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: e.key == active
                          ? LcColors.purple
                          : Colors.transparent,
                      width: 2.4,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    e.key,
                    style: TextStyle(
                      color: e.key == active
                          ? LcColors.purple
                          : LcColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
