import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/analytics/analytics_service.dart';
import '../../ui/zc_button.dart';
import '../../ui/zc_flag.dart';
import '../../ui/zc_theme.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';

/// Arguments passed from login to OTP via go_router `extra`.
class OtpArgs {
  const OtpArgs({required this.phone, required this.session});

  final String phone;
  final String session;
}

/// OTP Verification — pixel-matched to the otp_verification mockup:
/// secure pill, 3-step indicator, glowing lock hero, phone chip, 6 neon OTP
/// cells, resend countdown, gold VERIFY & CONTINUE, resend/change row and
/// the "Why OTP Verification?" info card.
///
/// Wired to POST /api/auth/otp/verify. Dev flavor: fixed code 123456.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _len = 6;
  static const _resendSeconds = 30;

  final _cells = List.generate(_len, (_) => TextEditingController());
  final _focus = List.generate(_len, (_) => FocusNode());
  late String _session = widget.args.session;
  bool _busy = false;

  Timer? _timer;
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    for (final f in _focus) {
      f.addListener(() => setState(() {})); // repaint focus border
    }
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _cells) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _mmss {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onChanged(int i, String v) {
    if (v.length > 1) {
      // Typing over a filled cell replaces it with the new digit.
      _cells[i].text = v[v.length - 1];
      _cells[i].selection = const TextSelection.collapsed(offset: 1);
      v = _cells[i].text;
    }
    if (v.isNotEmpty && i < _len - 1) _focus[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _focus[i - 1].requestFocus();
    setState(() {});
  }

  String get _code => _cells.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != _len) {
      _showError('Enter all 6 digits');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(_session, _code);
      if (mounted) {
        final isNew = ref.read(authControllerProvider).isNewUser;
        ref.read(analyticsServiceProvider).track('login_success');
        context.go(isNew ? '/profile-setup' : '/home');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() => _busy = true);
    try {
      _session = await ref
          .read(authControllerProvider.notifier)
          .requestOtp(widget.args.phone);
      for (final c in _cells) {
        c.clear();
      }
      _focus.first.requestFocus();
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Code resent'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: ZcColors.panelInput,
        ));
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

  String get _displayPhone {
    final p = widget.args.phone;
    if (p.startsWith('+91') && p.length == 13) {
      final d = p.substring(3);
      return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
    }
    return p;
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
                final s = (c.maxHeight / 860).clamp(0.62, 1.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      _topBar(),
                      SizedBox(height: 14 * s),
                      const _StepIndicator(current: 2),
                      SizedBox(height: 20 * s),
                      Center(
                        child: Image.asset('assets/art/lock_badge.png',
                            width: 150 * s, height: 150 * s),
                      ),
                      SizedBox(height: 16 * s),
                      Text('OTP Verification',
                          textAlign: TextAlign.center,
                          style: ZcText.heading(28 * s)),
                      SizedBox(height: 8 * s),
                      Text('Enter the 6-digit code sent to',
                          textAlign: TextAlign.center,
                          style: ZcText.body(14 * s)),
                      SizedBox(height: 12 * s),
                      Center(child: _phoneChip()),
                      SizedBox(height: 22 * s),
                      Row(
                        key: const Key('otpField'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _len; i++) ...[
                            if (i > 0) SizedBox(width: 9 * s),
                            _OtpCell(
                              controller: _cells[i],
                              focus: _focus[i],
                              onChanged: (v) => _onChanged(i, v),
                              s: s,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 18 * s),
                      Text("Didn't receive the code?",
                          textAlign: TextAlign.center,
                          style: ZcText.body(13 * s)),
                      SizedBox(height: 6 * s),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: 'Resend OTP in  ',
                              style: ZcText.body(14 * s)),
                          TextSpan(
                              text: _mmss,
                              style: ZcText.body(15 * s,
                                  color: ZcColors.gold,
                                  weight: FontWeight.w800)),
                        ]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16 * s),
                      _busy
                          ? const SizedBox(
                              height: 58,
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: ZcColors.gold),
                              ),
                            )
                          : ZcGoldButton(
                              key: const Key('verifyButton'),
                              label: 'VERIFY & CONTINUE',
                              onPressed: _verify,
                            ),
                      SizedBox(height: 16 * s),
                      _orDivider(s),
                      SizedBox(height: 12 * s),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _linkButton(
                            key: const Key('resendButton'),
                            icon: Icons.refresh_rounded,
                            iconColor: ZcColors.neonBlue,
                            label: 'Resend OTP',
                            onTap: (_busy || _secondsLeft > 0) ? null : _resend,
                          ),
                          Container(
                              width: 1, height: 22,
                              color: const Color(0x33FFFFFF),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 18)),
                          _linkButton(
                            icon: Icons.phone_iphone_rounded,
                            iconColor: ZcColors.gemPurple,
                            label: 'Change Number',
                            onTap: _busy ? null : () => context.pop(),
                          ),
                        ],
                        ),
                      ),
                      SizedBox(height: 18 * s),
                      const _WhyOtpCard(),
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

  Widget _topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.pop(),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x990D0330),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x40FFFFFF), width: 1.1),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  color: ZcColors.onlineGreen, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('100% Secure', style: ZcText.heading(12)),
                  Text('Your data is protected', style: ZcText.body(9.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phoneChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x80130B3B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x40FFFFFF), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ZcIndiaFlag(width: 26),
          const SizedBox(width: 10),
          Text(_displayPhone,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _orDivider(double s) {
    final line =
        Expanded(child: Container(height: 1, color: const Color(0x33FFFFFF)));
    return Row(children: [
      line,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('OR',
            style: ZcText.body(13 * s,
                color: ZcColors.gemPurple, weight: FontWeight.w800)),
      ),
      line,
    ]);
  }

  Widget _linkButton({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String label,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✓ —— ✓ —— 3 onboarding step indicator.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    Widget dot(bool done, String label) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? ZcColors.gemPurple : Colors.transparent,
          border: Border.all(
              color: done ? ZcColors.gemPurple : ZcColors.gemPurple,
              width: 1.6),
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
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
        ),
      );
    }

    Widget connector() => Container(
        width: 46, height: 2, color: ZcColors.gemPurple.withValues(alpha: 0.7));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(true, '1'),
        connector(),
        dot(true, '2'),
        connector(),
        dot(current >= 3, '3'),
      ],
    );
  }
}

/// "Why OTP Verification?" info card with green-check bullets.
class _WhyOtpCard extends StatelessWidget {
  const _WhyOtpCard();

  static const _points = [
    'Ensures the security of your account',
    'Prevents unauthorized access',
    'Helps us keep Zero Count safe for you',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xB3130B3B),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: ZcColors.neonPurple.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/art/shield_otp.png', width: 72, height: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why OTP Verification?', style: ZcText.heading(15)),
                const SizedBox(height: 8),
                for (final p in _points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: ZcColors.onlineGreen, size: 15),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(p,
                                style: ZcText.body(11.5).copyWith(height: 1.3))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.s,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final double s;

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    final hasFocus = focus.hasFocus;
    final active = hasFocus || filled;
    return Container(
      width: 48 * s,
      height: 60 * s,
      decoration: BoxDecoration(
        color: ZcColors.panelInput.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: active ? ZcColors.neonPurple : const Color(0x33FFFFFF),
          width: active ? 2 : 1.3,
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                    color: ZcColors.neonPurple.withValues(alpha: 0.55),
                    blurRadius: 14,
                    spreadRadius: 1)
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (controller.text.isEmpty && !hasFocus)
            Container(width: 12, height: 2.5, color: const Color(0x66FFFFFF)),
          TextField(
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            showCursor: hasFocus,
            cursorColor: Colors.white,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
