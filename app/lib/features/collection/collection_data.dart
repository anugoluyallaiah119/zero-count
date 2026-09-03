import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local (in-memory) collection catalog for Phase 2. Purchases stay
/// "Price Locked" until the store backend lands post-V2; owned / equipped /
/// favorites live only in this provider.

enum ZcRarity { rare, epic, legendary }

extension ZcRarityX on ZcRarity {
  String get label => switch (this) {
        ZcRarity.rare => 'Rare',
        ZcRarity.epic => 'Epic',
        ZcRarity.legendary => 'Legendary',
      };
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.name,
    required this.asset,
    required this.rarity,
    this.subtitle = '',
    this.price,
    this.owned = false,
    this.equipped = false,
    this.favorite = false,
  });

  final String id;
  final String name;
  final String asset;
  final ZcRarity rarity;
  final String subtitle;

  /// Coin price shown for unowned items (themes mockup).
  final int? price;
  final bool owned;
  final bool equipped;
  final bool favorite;

  CollectionItem copyWith({
    bool? owned,
    bool? equipped,
    bool? favorite,
  }) =>
      CollectionItem(
        id: id,
        name: name,
        asset: asset,
        rarity: rarity,
        subtitle: subtitle,
        price: price,
        owned: owned ?? this.owned,
        equipped: equipped ?? this.equipped,
        favorite: favorite ?? this.favorite,
      );
}

class CollectionCatalog {
  static const cardBacks = [
    CollectionItem(
        id: 'cb_brazil',
        name: 'Brazil Flag',
        asset: 'assets/art/card_back_brazil.png',
        rarity: ZcRarity.legendary,
        subtitle: 'Gold trim and Brazilian flag emblem.',
        owned: true,
        equipped: true),
    CollectionItem(
        id: 'cb_classic',
        name: 'Cosmic Swirl',
        asset: 'assets/art/cb_classic.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'cb_midnight',
        name: 'Midnight',
        asset: 'assets/art/cb_midnight.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'cb_cyber',
        name: 'Aurora',
        asset: 'assets/art/cb_cyber.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'cb_ember',
        name: 'Neon Grid',
        asset: 'assets/art/cb_ember.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'cb_ocean',
        name: 'Ocean Depths',
        asset: 'assets/art/cb_ocean.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'cb_royal',
        name: 'Fire Realm',
        asset: 'assets/art/cb_royal.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'cb_sakura',
        name: 'Golden Crown',
        asset: 'assets/art/cb_sakura.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'cb_gold',
        name: 'Void',
        asset: 'assets/art/cb_gold.png',
        rarity: ZcRarity.legendary),
  ];

  static const avatars = [
    CollectionItem(
        id: 'av_cyber',
        name: 'Cyber Zero',
        asset: 'assets/art/av_cyber.png',
        rarity: ZcRarity.epic,
        owned: true,
        equipped: true),
    CollectionItem(
        id: 'av_ace',
        name: 'Default',
        asset: 'assets/art/av_ace.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'av_fox',
        name: 'Neon Kid',
        asset: 'assets/art/av_fox.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'av_robot',
        name: 'Shadow',
        asset: 'assets/art/av_robot.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'av_queen',
        name: 'Aurora',
        asset: 'assets/art/av_queen.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'av_phoenix',
        name: 'Phoenix',
        asset: 'assets/art/av_phoenix.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'av_ninja',
        name: 'Ace',
        asset: 'assets/art/av_ninja.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'av_panda',
        name: 'Chill Zero',
        asset: 'assets/art/av_panda.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'av_alien',
        name: 'Quantum',
        asset: 'assets/art/av_alien.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'av_owl',
        name: 'Cosmic Girl',
        asset: 'assets/art/av_owl.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'av_king',
        name: 'Retro Player',
        asset: 'assets/art/av_king.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'av_knight',
        name: 'Samurai Zero',
        asset: 'assets/art/av_knight.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'av_wizard',
        name: 'Techie',
        asset: 'assets/art/av_wizard.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'av_tiger',
        name: 'Pumpkin Head',
        asset: 'assets/art/av_tiger.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'av_dragon',
        name: 'Ice Zero',
        asset: 'assets/art/av_dragon.png',
        rarity: ZcRarity.rare),
  ];

  static const themes = [
    CollectionItem(
        id: 'th_brazil_carnival',
        name: 'Brazil Carnival',
        asset: 'assets/art/home_brazil_banner.png',
        rarity: ZcRarity.legendary,
        subtitle: 'Rio de Janeiro Night. Feel the rhythm of Carnival.',
        owned: true,
        equipped: true),
    CollectionItem(
        id: 'th_galaxy',
        name: 'Cosmic Drift',
        asset: 'assets/art/th_galaxy.png',
        rarity: ZcRarity.epic,
        subtitle: 'A vast space to focus, think and win.',
        owned: true),
    CollectionItem(
        id: 'th_sakura',
        name: 'Sakura Calm',
        asset: 'assets/art/th_sakura_garden.png',
        rarity: ZcRarity.epic,
        subtitle: 'Peaceful vibes for a clear mind.',
        owned: true),
    CollectionItem(
        id: 'th_desert',
        name: 'Brazil Beats',
        asset: 'assets/art/th_desert_dusk.png',
        rarity: ZcRarity.epic,
        subtitle: 'Energetic colors. Feel the rhythm.',
        owned: true),
    CollectionItem(
        id: 'th_zen',
        name: 'Zen Garden',
        asset: 'assets/art/th_zen_garden.png',
        rarity: ZcRarity.rare,
        subtitle: 'Calm, minimal and focused.',
        owned: true),
    CollectionItem(
        id: 'th_neon',
        name: 'Neon City',
        asset: 'assets/art/th_neon_city.png',
        rarity: ZcRarity.epic,
        subtitle: 'Bright lights. Bigger moves.',
        price: 1000),
    CollectionItem(
        id: 'th_atlantis',
        name: 'Desert Mirage',
        asset: 'assets/art/th_atlantis.png',
        rarity: ZcRarity.rare,
        subtitle: 'Timeless arena of strategy.',
        price: 1200),
    CollectionItem(
        id: 'th_felt',
        name: 'Forest Whisper',
        asset: 'assets/art/th_classic_felt.png',
        rarity: ZcRarity.rare,
        subtitle: 'Breathe. Think. Win.',
        price: 750),
    CollectionItem(
        id: 'th_ocean',
        name: 'Ocean Depths',
        asset: 'assets/art/th_ocean_depths.png',
        rarity: ZcRarity.rare,
        subtitle: 'Dive deep into focus.',
        price: 750),
    CollectionItem(
        id: 'th_flow',
        name: 'Abstract Flow',
        asset: 'assets/art/th_abstract_flow.png',
        rarity: ZcRarity.epic,
        subtitle: 'Pure energy. No limits.',
        price: 1200),
  ];

  static const effects = [
    CollectionItem(
        id: 'ef_lightning',
        name: 'Electric Spark',
        asset: 'assets/art/ef_lightning.png',
        rarity: ZcRarity.epic,
        subtitle: 'Electrify every move and light up the arena.',
        owned: true,
        equipped: true),
    CollectionItem(
        id: 'ef_frost',
        name: 'Ice Shard',
        asset: 'assets/art/ef_frost.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'ef_fireworks',
        name: 'Fire Burst',
        asset: 'assets/art/ef_fireworks.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'ef_rainbow',
        name: 'Neon Trail',
        asset: 'assets/art/ef_rainbow.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'ef_hearts',
        name: 'Nature Flow',
        asset: 'assets/art/ef_hearts.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'ef_golden',
        name: 'Golden Glow',
        asset: 'assets/art/ef_golden.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'ef_confetti',
        name: 'Confetti',
        asset: 'assets/art/ef_confetti.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'ef_shadow',
        name: 'Dark Matter',
        asset: 'assets/art/ef_shadow.png',
        rarity: ZcRarity.epic),
  ];

  static const stickers = [
    CollectionItem(
        id: 'st_gg',
        name: 'GG Champ',
        asset: 'assets/art/st_gg.png',
        rarity: ZcRarity.epic,
        subtitle: 'Show your skills. Respect earned!',
        owned: true,
        equipped: true),
    CollectionItem(
        id: 'st_nice',
        name: 'Well Played!',
        asset: 'assets/art/st_nice.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'st_wow',
        name: 'No Way!',
        asset: 'assets/art/st_wow.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'st_fire',
        name: "Let's Go!",
        asset: 'assets/art/st_fire.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'st_lol',
        name: 'Thanks!',
        asset: 'assets/art/st_lol.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'st_cry',
        name: 'Oops!',
        asset: 'assets/art/st_cry.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'st_zero',
        name: 'Boom!',
        asset: 'assets/art/st_zero.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'st_think',
        name: 'Unlucky!',
        asset: 'assets/art/st_think.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'st_love',
        name: 'Take it Easy',
        asset: 'assets/art/st_love.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'st_angry',
        name: 'Fire!',
        asset: 'assets/art/st_angry.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'st_crown',
        name: 'Crown',
        asset: 'assets/art/st_crown.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'st_luck',
        name: '100 Points',
        asset: 'assets/art/st_luck.png',
        rarity: ZcRarity.rare),
  ];

  static const specialCards = [
    CollectionItem(
        id: 'sp_zero_classic',
        name: 'Cosmic Ace',
        asset: 'assets/art/sp_zero_classic.png',
        rarity: ZcRarity.epic,
        subtitle: 'A cosmic glow that lights up the table when you play it.',
        owned: true,
        equipped: true),
    CollectionItem(
        id: 'sp_zero_shadow',
        name: 'Inferno King',
        asset: 'assets/art/sp_zero_shadow.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'sp_double_zero',
        name: 'Forest Queen',
        asset: 'assets/art/sp_double_zero.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'sp_zero_gold',
        name: 'Thunder Jack',
        asset: 'assets/art/sp_zero_gold.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'sp_reverse',
        name: 'Golden 10',
        asset: 'assets/art/sp_reverse.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'sp_shield',
        name: 'Frost 9',
        asset: 'assets/art/sp_shield.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'sp_thief',
        name: 'Neon 8',
        asset: 'assets/art/sp_thief.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'sp_mirror',
        name: 'Blossom 7',
        asset: 'assets/art/sp_mirror.png',
        rarity: ZcRarity.epic,
        owned: true),
    CollectionItem(
        id: 'sp_zero_lightning',
        name: 'Shadow 6',
        asset: 'assets/art/sp_zero_lightning.png',
        rarity: ZcRarity.rare,
        owned: true),
    CollectionItem(
        id: 'sp_zero_frost',
        name: 'Crystal 5',
        asset: 'assets/art/sp_zero_frost.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'sp_zero_nature',
        name: 'Lava 4',
        asset: 'assets/art/sp_zero_nature.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'sp_zero_royal',
        name: 'Royal 3',
        asset: 'assets/art/sp_zero_royal.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'sp_blackhole',
        name: 'Pulse 2',
        asset: 'assets/art/sp_blackhole.png',
        rarity: ZcRarity.rare),
    CollectionItem(
        id: 'sp_prism',
        name: 'Radiant Ace',
        asset: 'assets/art/sp_prism.png',
        rarity: ZcRarity.legendary),
    CollectionItem(
        id: 'sp_mirror_silver',
        name: 'Mystic Joker',
        asset: 'assets/art/sp_mirror_silver.png',
        rarity: ZcRarity.epic),
    CollectionItem(
        id: 'sp_phoenix',
        name: 'Phoenix Zero',
        asset: 'assets/art/sp_phoenix.png',
        rarity: ZcRarity.legendary),
  ];
}

/// Holds the user's live collection state (favorites + equipped flags).
/// Seeded from the static catalog; all mutations are local-only.
class CollectionController extends Notifier<Map<String, List<CollectionItem>>> {
  @override
  Map<String, List<CollectionItem>> build() => {
        'cardBacks': List.of(CollectionCatalog.cardBacks),
        'avatars': List.of(CollectionCatalog.avatars),
        'themes': List.of(CollectionCatalog.themes),
        'effects': List.of(CollectionCatalog.effects),
        'stickers': List.of(CollectionCatalog.stickers),
        'specialCards': List.of(CollectionCatalog.specialCards),
      };

  void toggleFavorite(String category, String id) {
    final list = state[category]!;
    state = {
      ...state,
      category: [
        for (final it in list)
          it.id == id ? it.copyWith(favorite: !it.favorite) : it,
      ],
    };
  }

  void equip(String category, String id) {
    final list = state[category]!;
    final target = list.firstWhere((e) => e.id == id);
    if (!target.owned) return;
    state = {
      ...state,
      category: [
        for (final it in list)
          it.copyWith(equipped: it.id == id),
      ],
    };
  }
}

final collectionProvider =
    NotifierProvider<CollectionController, Map<String, List<CollectionItem>>>(
        CollectionController.new);
