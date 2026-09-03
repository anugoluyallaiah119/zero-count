import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/analytics/analytics_service.dart';
import '../../ui/zc_button.dart';
import '../../ui/zc_flag.dart';
import '../../ui/zc_theme.dart';
import '../player/profile_repository.dart';
import 'avatar_catalog.dart';

/// Profile Setup — pixel-matched to the profile_setup mockup: 4-step
/// indicator, big avatar in a gold ring with camera badge, name field,
/// 10-avatar picker grid, locked "Optional Customization" tiles and the
/// gold LET'S PLAY button.
///
/// Saves via PATCH /api/players/me (E2.4).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  int _avatarIndex = 0;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .update(name: name, avatar: kAvatars[_avatarIndex].id);
      ref.invalidate(profileProvider);
      ref.read(analyticsServiceProvider).track('profile_setup_done');
      if (mounted) context.go('/home');
    } on ProfileException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ZcColors.errorRed,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/art/bg_splash.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x5508051E), Color(0xE608051E)],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final s = (c.maxHeight / 880).clamp(0.58, 1.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const _TopBar(),
                      SizedBox(height: 14 * s),
                      const _StepDots(),
                      SizedBox(height: 14 * s),
                      Text('Profile Setup',
                          textAlign: TextAlign.center,
                          style: ZcText.heading(28 * s)),
                      SizedBox(height: 4 * s),
                      Text("Let's make it yours!",
                          textAlign: TextAlign.center,
                          style: ZcText.body(14 * s)),
                      SizedBox(height: 16 * s),
                      _heroAvatar(s),
                      SizedBox(height: 18 * s),
                      _nameField(s),
                      SizedBox(height: 20 * s),
                      Text('Choose Your Avatar', style: ZcText.heading(17 * s)),
                      SizedBox(height: 3 * s),
                      Text('Pick a style that feels like you.',
                          style: ZcText.body(12.5 * s)),
                      SizedBox(height: 14 * s),
                      _avatarGrid(s),
                      SizedBox(height: 20 * s),
                      Text('Optional Customization',
                          style: ZcText.heading(17 * s)),
                      SizedBox(height: 12 * s),
                      _customizationRow(s),
                      SizedBox(height: 22 * s),
                      _busy
                          ? const SizedBox(
                              height: 58,
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: ZcColors.gold),
                              ),
                            )
                          : ZcGoldButton(
                              key: const Key('saveProfileButton'),
                              label: "LET'S PLAY",
                              onPressed: _save,
                            ),
                      SizedBox(height: 16 * s),
                      _footer(s),
                      const SizedBox(height: 18),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroAvatar(double s) {
    final size = 150.0 * s;
    return Center(
      child: SizedBox(
        width: size + 44,
        height: size + 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ZcColors.gold, width: 4),
                boxShadow: [
                  BoxShadow(
                      color: ZcColors.neonPink.withValues(alpha: 0.45),
                      blurRadius: 30,
                      spreadRadius: 2),
                ],
              ),
              child: ClipOval(
                child: Image.asset(kAvatars[_avatarIndex].asset,
                    fit: BoxFit.cover),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                width: 44 * s + 12,
                height: 44 * s + 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7B2FF7), Color(0xFF4A11B8)],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameField(double s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: ZcColors.panelInput.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: ZcColors.neonPurple.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: ZcColors.gemPurple, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('nameField'),
              controller: _nameController,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _save(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Your Name',
                labelStyle: ZcText.body(12 * s),
                hintText: 'Rahul',
                hintStyle: ZcText.body(15 * s),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarGrid(double s) {
    const cols = 5;
    final rows = <Widget>[];
    for (var r = 0; r * cols < kAvatars.length; r++) {
      final children = <Widget>[];
      for (var cIdx = 0; cIdx < cols; cIdx++) {
        final i = r * cols + cIdx;
        if (i >= kAvatars.length) break;
        children.add(Expanded(child: _avatarCell(i, s)));
      }
      while (children.length < cols) {
        children.add(const Expanded(child: SizedBox()));
      }
      rows.add(Row(children: children));
      if (r * cols + cols < kAvatars.length) rows.add(SizedBox(height: 14 * s));
    }
    return Column(children: rows);
  }

  Widget _avatarCell(int i, double s) {
    final selected = i == _avatarIndex;
    final d = 58.0 * s;
    return GestureDetector(
      key: Key('avatarOption$i'),
      onTap: () => setState(() => _avatarIndex = i),
      child: SizedBox(
        height: d + 14,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? ZcColors.gold : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: ZcColors.gold.withValues(alpha: 0.5),
                            blurRadius: 12)
                      ]
                    : null,
              ),
              child: ClipOval(
                child: Image.asset(kAvatars[i].asset, fit: BoxFit.cover),
              ),
            ),
            if (selected)
              Positioned(
                right: 2,
                bottom: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: ZcColors.gold,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: ZcColors.goldText, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customizationRow(double s) {
    Widget tile(String assetOrIcon, String label) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.fromLTRB(10, 12, 8, 10),
          decoration: BoxDecoration(
            color: ZcColors.panelInput.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: const Color(0x33FFFFFF), width: 1.1),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: Center(
                        child: assetOrIcon.endsWith('.png')
                            ? Image.asset(assetOrIcon, height: 36 * s)
                            : Icon(
                                assetOrIcon == 'frame'
                                    ? Icons.radio_button_unchecked
                                    : Icons.auto_awesome_rounded,
                                color: ZcColors.gold,
                                size: 34 * s),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white54, size: 18),
                  ]),
                  SizedBox(height: 10 * s),
                  Row(children: [
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white54, size: 16),
                  ]),
                ],
              ),
              // Locked badge — pink circle overlapping the tile corner.
              Positioned(
                top: -20,
                right: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ZcColors.neonPink,
                    border: Border.all(
                        color: ZcColors.panelInput, width: 2),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(children: [
      tile('frame', 'Avatar Frame'),
      tile('assets/art/card_back.png', 'Card Back'),
      tile('effect', 'Victory Effect'),
    ]);
  }

  Widget _footer(double s) {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 1,
              color: ZcColors.gold.withValues(alpha: 0.35),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.workspace_premium_rounded,
                color: ZcColors.gold, size: 22),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: ZcColors.gold.withValues(alpha: 0.35),
            ),
          ),
        ]),
        SizedBox(height: 8 * s),
        Text('Your journey to Zero Count begins now!',
            textAlign: TextAlign.center, style: ZcText.body(12 * s)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (context.canPop()) context.pop();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x990D0330),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: const Color(0x40FFFFFF), width: 1.1),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0x990D0330),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x40FFFFFF), width: 1.1),
          ),
          child: const Row(
            children: [
              ZcIndiaFlag(width: 22),
              SizedBox(width: 8),
              Text('English',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

/// ✓ — ✓ — ✓ — 4 onboarding step indicator (all account steps done).
class _StepDots extends StatelessWidget {
  const _StepDots();

  @override
  Widget build(BuildContext context) {
    Widget dot(bool done, String label) => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? ZcColors.gemPurple : Colors.transparent,
            border: Border.all(color: ZcColors.gemPurple, width: 1.6),
            boxShadow: done
                ? [
                    BoxShadow(
                        color: ZcColors.neonPurple.withValues(alpha: 0.5),
                        blurRadius: 10)
                  ]
                : null,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16)
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
          ),
        );
    Widget connector() => Container(
        width: 40, height: 2, color: ZcColors.gemPurple.withValues(alpha: 0.7));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(true, '1'),
        connector(),
        dot(true, '2'),
        connector(),
        dot(true, '3'),
        connector(),
        dot(false, '4'),
      ],
    );
  }
}
