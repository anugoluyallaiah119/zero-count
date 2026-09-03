import 'package:flutter/material.dart';

/// Avatar catalog — stored server-side by id (E2.4 `avatar` column).
/// V2 uses the 10 generated avatar art assets (avatar_01..10). Legacy V1 ids
/// (smile/cool/star/bolt/crown/rocket) still resolve so existing accounts
/// keep rendering after upgrade.
class AvatarOption {
  const AvatarOption(this.id, this.asset);
  final String id;
  final String asset;
}

const kAvatars = <AvatarOption>[
  AvatarOption('hoodie', 'assets/art/avatar_01.png'),
  AvatarOption('longhair', 'assets/art/avatar_02.png'),
  AvatarOption('sunglasses', 'assets/art/avatar_03.png'),
  AvatarOption('yellowcap', 'assets/art/avatar_04.png'),
  AvatarOption('curly', 'assets/art/avatar_05.png'),
  AvatarOption('bearded', 'assets/art/avatar_06.png'),
  AvatarOption('bun', 'assets/art/avatar_07.png'),
  AvatarOption('fedora', 'assets/art/avatar_08.png'),
  AvatarOption('astronaut', 'assets/art/avatar_09.png'),
  AvatarOption('tiger', 'assets/art/avatar_10.png'),
];

/// Legacy V1 id → V2 asset mapping.
const _legacy = <String, String>{
  'smile': 'assets/art/avatar_01.png',
  'cool': 'assets/art/avatar_02.png',
  'star': 'assets/art/avatar_03.png',
  'bolt': 'assets/art/avatar_05.png',
  'crown': 'assets/art/avatar_08.png',
  'rocket': 'assets/art/avatar_09.png',
};

/// Resolve a stored avatar id to its art asset (defaults to the first).
String avatarAsset(String id) {
  for (final a in kAvatars) {
    if (a.id == id) return a.asset;
  }
  return _legacy[id] ?? kAvatars.first.asset;
}

/// Circular avatar from art asset (used by home, lobby, live game).
class ZcAvatar extends StatelessWidget {
  const ZcAvatar({super.key, required this.id, this.size = 44, this.border});

  final String id;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(avatarAsset(id), fit: BoxFit.cover),
      ),
    );
  }
}

/// Legacy resolver kept for callers that still show icons in tests.
IconData avatarIcon(String id) => Icons.person_rounded;

/// Stable art avatar for an id that is not in the catalog (e.g. room member
/// user ids, which the room contract carries without an avatar field).
String kAvatarFor(String id) => kAvatars[id.hashCode.abs() % kAvatars.length].asset;
