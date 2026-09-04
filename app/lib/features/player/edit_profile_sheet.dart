import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/analytics/analytics_service.dart';
import '../../ui/zc_cosmetics.dart';
import '../../ui/zc_theme.dart';
import '../auth/avatar_catalog.dart';
import '../player/profile_repository.dart';

/// Edit sheet — name + avatar picker, available from the profile screen.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.profile});
  final PlayerProfile profile;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _name;
  String _selectedAvatarId = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _selectedAvatarId = widget.profile.avatar.isNotEmpty
        ? widget.profile.avatar
        : 'av_default';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).update(
            name: trimmed,
            avatar: _selectedAvatarId,
          );
      ref.invalidate(profileProvider);
      ref
          .read(analyticsServiceProvider)
          .track('profile_updated', {'avatar': _selectedAvatarId});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ZcColors.errorRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // All known avatar ids: legacy image-based + new ZcAvatars code-drawn.
  static const _allAvatarIds = [
    'av_default', 'av_cyber', 'av_fox', 'av_robot', 'av_queen',
    'av_panda', 'av_ninja', 'av_king', 'av_wizard', 'av_tiger',
    'av_owl', 'av_alien', 'av_knight', 'av_phoenix', 'av_dragon',
    // Legacy image-based avatars (still valid)
    'hoodie', 'longhair', 'sunglasses', 'yellowcap', 'curly',
    'bearded', 'bun', 'fedora', 'astronaut', 'tiger',
  ];

  Widget _renderAvatar(String id, double size) {
    if (id.startsWith('av_')) return ZcAvatars.forId(id, size);
    // Legacy: find image asset from catalog.
    final opt = kAvatars.firstWhere((a) => a.id == id,
        orElse: () => kAvatars.first);
    return Image.asset(opt.asset,
        width: size, height: size, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A0B3D), Color(0xFF09031E)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'EDIT PROFILE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: ZcColors.gold))
                          : const Text('SAVE',
                              style: TextStyle(
                                color: ZcColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              )),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  children: [
                    // Current avatar preview
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: ZcColors.gold, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: ZcColors.gold.withValues(alpha: 0.4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child:
                              _renderAvatar(_selectedAvatarId, 80),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Name field
                    TextField(
                      controller: _name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                      cursorColor: ZcColors.gold,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: const TextStyle(
                            color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0x22FFFFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0x33FFFFFF)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0x33FFFFFF)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: ZcColors.gold, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CHOOSE AVATAR',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: _allAvatarIds.length,
                      itemBuilder: (context, i) {
                        final id = _allAvatarIds[i];
                        final selected = id == _selectedAvatarId;
                        return GestureDetector(
                          onTap: () => setState(
                              () => _selectedAvatarId = id),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? ZcColors.gold
                                    : const Color(0x22FFFFFF),
                                width: selected ? 2.5 : 1.2,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: ZcColors.gold
                                            .withValues(alpha: 0.5),
                                        blurRadius: 10,
                                      )
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: _renderAvatar(id, 56),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
