import 'package:flutter/material.dart';

import 'zc_card_backs.dart';
import 'zc_cosmetics.dart';

/// Available card suits.
enum ZcSuit {
  hearts,
  diamonds,
  clubs,
  spades;

  bool get isRed => this == hearts || this == diamonds;
  Color get color => isRed ? const Color(0xFFE53935) : const Color(0xFF1E1B4B);
  String get symbol {
    switch (this) {
      case hearts:
        return '♥';
      case diamonds:
        return '♦';
      case clubs:
        return '♣';
      case spades:
        return '♠';
    }
  }
}

/// Visual suit emblem with high contrast.
class SuitIcon extends StatelessWidget {
  const SuitIcon(
    this.suit, {
    super.key,
    this.width = 16,
  });

  final ZcSuit suit;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Text(
      suit.symbol,
      style: TextStyle(
        fontSize: width * 1.02,
        color: suit.color,
        height: 1.0,
        fontWeight: FontWeight.w900,
        fontFamily: 'Nunito',
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// A crisp, physical playing card matching the mockup and index.html spec.
/// When selected, pops up by -18px with a radiant gold border and glowing halo.
class ZcPlayingCard extends StatelessWidget {
  const ZcPlayingCard({
    super.key,
    required this.rank,
    required this.suit,
    required this.value,
    this.isSpecial = false,
    this.specialSkinId = 'sp_classic',
    this.width = 52,
    this.selected = false,
    this.faceDown = false,
    this.cardBackId = 'cb_classic',
    this.elevation = 0.0,
    this.onTap,
  });

  final String rank;
  final ZcSuit suit;
  final int value;
  final bool isSpecial;
  /// Equipped special card skin id — drives gradient, star colour, label.
  final String specialSkinId;
  final double width;
  final bool selected;
  final bool faceDown;
  /// Card back cosmetic id — maps to a ZcCardBacks painter.
  final String cardBackId;
  final double elevation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.44;
    final radius = width * 0.16;
    final skin = isSpecial ? ZcSpecialSkin.forId(specialSkinId) : null;

    final specialGradient = skin?.gradient ?? const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2A0A4B), Color(0xFF13033B)],
    );
    final starColor = skin?.starColor ?? const Color(0xFF2EEA6A);
    final specialLabel = skin?.label ?? '★';
    final Widget faceContent = faceDown
        ? ZcCardBackWidget(backId: cardBackId, width: width)
        : Container(
            decoration: BoxDecoration(
              color: isSpecial ? null : Colors.white,
              gradient: isSpecial ? specialGradient : null,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFDE047)
                    : isSpecial
                        ? (skin?.glowColor ?? const Color(0xFFD946CB))
                        : const Color(0xFFCBC8D4),
                width: selected ? 2.2 : 1.2,
              ),
              boxShadow: [
                if (selected) ...[
                  BoxShadow(
                    color: const Color(0xFFFDE047).withValues(alpha: 0.85),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 3,
                  ),
                ] else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 6,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: isSpecial
                // ── Special card layout (unchanged) ──────────────────────
                ? Padding(
                    padding: EdgeInsets.fromLTRB(
                        width * 0.08, width * 0.07, width * 0.08, width * 0.07),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              specialLabel,
                              style: TextStyle(
                                fontSize: width * 0.30,
                                fontWeight: FontWeight.w900,
                                color: starColor,
                                height: 1.0,
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            specialLabel,
                            style: TextStyle(
                              fontSize: width * 0.56,
                              fontWeight: FontWeight.w900,
                              color: starColor,
                              height: 1.0,
                              shadows: [Shadow(color: starColor, blurRadius: 12)],
                            ),
                          ),
                        ),
                        // Bottom-right value badge for specials
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: width * 0.33,
                            height: width * 0.33,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFFDE047)
                                  : const Color(0xFF1E1B4B),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: selected
                                      ? const Color(0xFFB45309)
                                      : const Color(0x40FFFFFF),
                                  width: 0.8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'S',
                              style: TextStyle(
                                fontSize: width * 0.18,
                                fontWeight: FontWeight.w900,
                                color: selected
                                    ? const Color(0xFF1E1B4B)
                                    : const Color(0xFFFDE047),
                                fontFamily: 'Nunito',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                // ── Standard card — clean physical layout with value badge ─
                : Stack(
                    children: [
                      // Top-left corner: rank + suit
                      Positioned(
                        top: width * 0.08,
                        left: width * 0.08,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rank,
                              style: TextStyle(
                                fontSize: width * 0.285,
                                fontWeight: FontWeight.w900,
                                color: suit.color,
                                height: 1.0,
                                fontFamily: 'Nunito',
                              ),
                            ),
                            SuitIcon(suit, width: width * 0.20),
                          ],
                        ),
                      ),

                      // Center: large suit pip
                      Center(
                        child: SuitIcon(suit, width: width * 0.46),
                      ),

                      // Bottom-right corner: Point value badge (A=1, 2..10, J/Q/K=10)
                      Positioned(
                        right: width * 0.06,
                        bottom: width * 0.06,
                        child: Container(
                          width: width * 0.33,
                          height: width * 0.33,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFDE047)
                                : const Color(0xFF1E1B4B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFB45309)
                                  : const Color(0x40FFFFFF),
                              width: 0.8,
                            ),
                            boxShadow: [
                              if (selected)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$value',
                            style: TextStyle(
                              fontSize: width * 0.18,
                              fontWeight: FontWeight.w900,
                              color: selected
                                  ? const Color(0xFF1E1B4B)
                                  : const Color(0xFFFDE047),
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          );

    final cardWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      transform: selected
          ? (Matrix4.identity()..translateByDouble(0.0, -18.0, 0, 0))
          : Matrix4.identity(),
      child: faceContent,
    );

    if (onTap == null) return cardWidget;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cardWidget,
    );
  }
}

/// A grouped stack of cards with the same rank (e.g. three 2s or four 7s).
/// Saves horizontal hand space with fan indicator and count badge.
class ZcGroupedCardStack extends StatelessWidget {
  const ZcGroupedCardStack({
    super.key,
    required this.cards,
    this.cardWidth = 52,
    this.selectedCardId,
    this.onCardTap,
  });

  final List<({int id, String rank, ZcSuit suit, int value, bool isSpecial})> cards;
  final double cardWidth;
  final int? selectedCardId;
  final ValueChanged<int>? onCardTap;

  @override
  Widget build(BuildContext context) {
    final height = cardWidth * 1.44;
    const double step = 11.0;
    final totalWidth = cardWidth + step * (cards.length - 1);

    return SizedBox(
      width: totalWidth,
      height: height + 24.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomLeft,
        children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: i * step,
              bottom: 0,
              child: ZcPlayingCard(
                rank: cards[i].rank,
                suit: cards[i].suit,
                value: cards[i].value,
                isSpecial: cards[i].isSpecial,
                width: cardWidth,
                selected: selectedCardId == cards[i].id,
                onTap: () => onCardTap?.call(cards[i].id),
              ),
            ),
          // Group badge
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA855F7), Color(0xFF6B21A8)],
                ),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFFDE047), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66FDE047),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFDE047), size: 10),
                  const SizedBox(width: 2),
                  Text(
                    '×${cards.length} (0pt)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
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

/// A clean, uncompressed card fan matching index.html spec.
/// Automatically renders 2 tiers for 13-card games (43px) and 1 tier for 7-card games (52px).
class ZcCardFan extends StatelessWidget {
  const ZcCardFan({
    super.key,
    required this.cards,
    this.cardWidth = 52,
    this.overlap = 0.62,
    this.fanAngle = 0.0,
    this.enableGrouping = true,
    this.selectedIndex,
    this.selectedCardId,
    this.onCardTap,
  });

  final List<dynamic> cards;
  final double cardWidth;
  final double overlap;
  final double fanAngle;
  final bool enableGrouping;
  final int? selectedIndex;
  final int? selectedCardId;
  final ValueChanged<int>? onCardTap;

  List<({int id, String rank, ZcSuit suit, int value, bool isSpecial})> _normalizeCards() {
    final List<({int id, String rank, ZcSuit suit, int value, bool isSpecial})> result = [];
    for (var i = 0; i < cards.length; i++) {
      final item = cards[i];
      if (item is ({int id, String rank, ZcSuit suit, int value, bool isSpecial})) {
        result.add(item);
      } else if (item is (String, ZcSuit, int)) {
        result.add((id: i, rank: item.$1, suit: item.$2, value: item.$3, isSpecial: false));
      } else if (item is ({int id, String rank, dynamic suit, int value, bool isSpecial})) {
        result.add((id: item.id, rank: item.rank, suit: item.suit as ZcSuit, value: item.value, isSpecial: item.isSpecial));
      } else if (item is ({int id, String rank, dynamic suit, int value})) {
        result.add((id: item.id, rank: item.rank, suit: item.suit as ZcSuit, value: item.value, isSpecial: false));
      } else {
        try {
          result.add((
            id: (item.id as int?) ?? i,
            rank: item.rank.toString(),
            suit: item.suit as ZcSuit,
            value: item.value as int,
            isSpecial: (item.isSpecial as bool?) ?? false,
          ));
        } catch (_) {
          result.add((id: i, rank: 'A', suit: ZcSuit.hearts, value: 1, isSpecial: false));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeCards();
    if (normalized.isEmpty) return const SizedBox();

    // Grouping analysis: Group identical ranks where count >= 3, including
    // special-completed groups (2 same rank + 1 special). Specials are
    // displayed as loose cards so they remain selectable.
    final Map<String, List<({int id, String rank, ZcSuit suit, int value, bool isSpecial})>> rankBuckets = {};
    for (final c in normalized) {
      if (c.isSpecial) continue;
      rankBuckets.putIfAbsent(c.rank, () => []).add(c);
    }
    final specials = normalized.where((c) => c.isSpecial).toList();

    final hasGroups = enableGrouping &&
        (rankBuckets.values.any((list) => list.length >= 3) ||
            specials.isNotEmpty);

    final List<Widget> items = [];
    final processedRanks = <String>{};

    for (var i = 0; i < normalized.length; i++) {
      final c = normalized[i];
      if (hasGroups && rankBuckets[c.rank]!.length >= 3) {
        if (!processedRanks.contains(c.rank)) {
          processedRanks.add(c.rank);
          items.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: ZcGroupedCardStack(
                cards: rankBuckets[c.rank]!,
                cardWidth: cardWidth,
                selectedCardId: selectedCardId,
                onCardTap: onCardTap,
              ),
            ),
          );
        }
      } else {
        final isSelected = selectedCardId != null
            ? selectedCardId == c.id
            : selectedIndex == i;

        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ZcPlayingCard(
              rank: c.rank,
              suit: c.suit,
              value: c.value,
              isSpecial: c.isSpecial,
              width: cardWidth,
              selected: isSelected,
              onTap: onCardTap == null ? null : () => onCardTap!(c.id),
            ),
          ),
        );
      }
    }

    // 2-row layout for 13-card games (or large hands) so all cards fit without scrolling
    if (items.length > 7) {
      final mid = (items.length + 1) ~/ 2;
      final row1 = items.sublist(0, mid);
      final row2 = items.sublist(mid);

      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: row1,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: row2,
            ),
          ],
        ),
      );
    }

    // Single centered row for 7-card games (or smaller hands)
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 3),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: items,
        ),
      ),
    );
  }
}
