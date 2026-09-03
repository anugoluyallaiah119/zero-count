import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/zc_button.dart';
import '../../ui/zc_flag.dart';
import '../../ui/zc_theme.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';
import 'otp_screen.dart';

/// Login / Sign Up — pixel-matched to the login_screen mockup:
/// back button + language pill, hero logo, tagline, glass panel with phone
/// input, gold CONTINUE, OTP note, "Why play Zero Count?" features, privacy
/// box and terms line.
///
/// Wired to POST /api/auth/otp/request. Dev flavor accepts any 10-digit
/// number; the dev provider's fixed code is 123456.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final digits = _phoneController.text.trim();
    if (digits.length != 10) {
      _showError('Enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _busy = true);
    try {
      final phone = '+91$digits';
      final session =
          await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (mounted) {
        unawaited(
            context.push('/otp', extra: OtpArgs(phone: phone, session: session)));
      }
    } on AuthException catch (e) {
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
          // Same purple carnival night backdrop as splash.
          Image.asset('assets/art/bg_splash.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xCC08051E)],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final s = (c.maxHeight / 860).clamp(0.62, 1.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const _TopBar(),
                      SizedBox(height: 6 * s),
                      Center(
                        child: Image.asset(
                          'assets/art/logo.png',
                          key: const Key('loginLogo'),
                          width: 340 * s + 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '≫  ', style: ZcText.body(15 * s, color: ZcColors.gold)),
                          TextSpan(
                              text: 'Collect, Group & Count ',
                              style: ZcText.body(15 * s,
                                  color: Colors.white, weight: FontWeight.w800)),
                          TextSpan(
                              text: 'Low!',
                              style: ZcText.body(15 * s,
                                  color: ZcColors.gold, weight: FontWeight.w800)),
                          TextSpan(
                              text: '  ≪', style: ZcText.body(15 * s, color: ZcColors.gold)),
                        ]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 18 * s),
                      _buildPanel(s),
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

  Widget _buildPanel(double s) {
    return Container(
      padding: EdgeInsets.fromLTRB(20 * s, 22 * s, 20 * s, 16 * s),
      decoration: BoxDecoration(
        color: const Color(0xB30D0330),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x40FFFFFF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Login / Sign Up',
              textAlign: TextAlign.center, style: ZcText.heading(26 * s)),
          SizedBox(height: 8 * s),
          Text('Enter your mobile number to continue',
              textAlign: TextAlign.center, style: ZcText.body(14 * s)),
          SizedBox(height: 20 * s),
          _PhoneField(controller: _phoneController, onSubmit: _continue),
          SizedBox(height: 18 * s),
          _busy
              ? const SizedBox(
                  height: 58,
                  child: Center(
                    child: CircularProgressIndicator(color: ZcColors.gold),
                  ),
                )
              : ZcGoldButton(
                  key: const Key('sendOtpButton'),
                  label: 'CONTINUE',
                  onPressed: _continue,
                ),
          SizedBox(height: 14 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_rounded,
                  size: 16, color: ZcColors.textSecondary),
              const SizedBox(width: 7),
              Flexible(
                child: Text('We will send you an OTP to verify your number',
                    textAlign: TextAlign.center,
                    style: ZcText.body(11.5 * s)),
              ),
            ],
          ),
          SizedBox(height: 18 * s),
          _dividerLabel('Why play Zero Count?', s),
          SizedBox(height: 14 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Feature(icon: 'assets/art/icon_aces.png',
                  line1: 'Easy to learn', line2: 'Fun to master', s: s),
              _Feature(icon: 'assets/art/icon_players.png',
                  line1: 'Play with', line2: 'real players', s: s),
              _Feature(icon: 'assets/art/icon_trophy.png',
                  line1: 'Win rewards', line2: '& climb ranks', s: s),
              _Feature(icon: 'assets/art/icon_reward.png',
                  line1: 'Earn coins', line2: '& unlock more', s: s),
            ],
          ),
          SizedBox(height: 16 * s),
          const _PrivacyBox(),
          SizedBox(height: 16 * s),
          Text.rich(
            TextSpan(
              style: ZcText.body(12 * s),
              children: [
                const TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                    text: 'Terms of Service',
                    style: ZcText.body(12 * s, color: ZcColors.gold)),
                const TextSpan(text: '\nand '),
                TextSpan(
                    text: 'Privacy Policy',
                    style: ZcText.body(12 * s, color: ZcColors.gold)),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _dividerLabel(String label, double s) {
    final line = Expanded(
      child: Container(height: 1, color: const Color(0x33FFFFFF)),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: ZcText.body(13 * s,
                  color: ZcColors.gemPurple, weight: FontWeight.w800)),
        ),
        line,
      ],
    );
  }
}

/// Back button (left) + English language pill (right).
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _outlineSquare(
          child: const Icon(Icons.chevron_left_rounded,
              color: Colors.white, size: 26),
          onTap: () {
            if (context.canPop()) context.pop();
          },
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

  static Widget _outlineSquare({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0x990D0330),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x40FFFFFF), width: 1.1),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Country prefix + phone input as one bordered control with a divider.
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ZcColors.panelInput,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x40FFFFFF), width: 1.2),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: ZcIndiaFlag(width: 26),
          ),
          const SizedBox(width: 8),
          const Text('+91',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Container(width: 1, height: 30, color: const Color(0x33FFFFFF)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('phoneField'),
              controller: controller,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1),
              decoration: const InputDecoration(
                hintText: 'Mobile Number',
                hintStyle: TextStyle(color: ZcColors.textSecondary),
                border: InputBorder.none,
                counterText: '',
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Purple gradient feature tile with icon + two-line caption.
class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.line1,
    required this.line2,
    required this.s,
  });

  final String icon;
  final String line1;
  final String line2;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 62 * s,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7B2FF7), Color(0xFF4A11B8)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66B04DFF), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: ZcColors.neonPurple.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(icon, height: 46 * s, fit: BoxFit.contain),
            ),
          ),
          SizedBox(height: 8 * s),
          Text('$line1\n$line2',
              textAlign: TextAlign.center,
              style: ZcText.body(10.5 * s, color: Colors.white)
                  .copyWith(height: 1.35)),
        ],
      ),
    );
  }
}

/// "Your data is 100% secure" privacy assurance box.
class _PrivacyBox extends StatelessWidget {
  const _PrivacyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0x80130B3B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2EFFFFFF), width: 1.1),
      ),
      child: Row(
        children: [
          Image.asset('assets/art/lock_badge.png', width: 38, height: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your data is 100% secure',
                    style: ZcText.heading(13.5)),
                const SizedBox(height: 3),
                Text('We respect your privacy and never share your information.',
                    style: ZcText.body(11).copyWith(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
