import 'package:flutter/material.dart';

import 'zc_theme.dart';

/// The signature gold CTA button (CONTINUE / JOIN ROOM / VERIFY & CONTINUE).
class ZcGoldButton extends StatelessWidget {
  const ZcGoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.showArrow = true,
    this.enabled = true,
    this.height = 58,
    this.fontSize = 17,
  });

  /// Label size in px — drop to ~13 for narrow half-width panels.
  final double fontSize;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool showArrow;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: ZcColors.goldGradient,
          borderRadius: BorderRadius.circular(ZcRadii.button),
          border: Border.all(color: ZcColors.goldDark, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: ZcColors.goldDark.withValues(alpha: 0.40),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ZcRadii.button),
            onTap: enabled ? onPressed : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 10)],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        style: ZcText.display(fontSize,
                            color: ZcColors.goldText)),
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded,
                      color: ZcColors.goldText, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Neon-outline secondary button (COPY LINK, JOIN, SORT, etc).
class ZcOutlineButton extends StatelessWidget {
  const ZcOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = ZcColors.neonPurple,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.25) : ZcColors.panelInput,
        borderRadius: BorderRadius.circular(ZcRadii.chip),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ZcRadii.chip),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(label, style: ZcText.heading(13).copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top-bar currency pill: [coin/gem icon] value [+].
class ZcCurrencyPill extends StatelessWidget {
  const ZcCurrencyPill({
    super.key,
    required this.icon,
    required this.value,
    this.onTap,
  });

  final Widget icon;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: ZcColors.panelInput,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZcColors.neonPurpleDim, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 28, height: 28, child: icon),
          const SizedBox(width: 6),
          Text(value, style: ZcText.heading(14)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: ZcColors.neonPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
