import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Shared bottom-sheet chrome: 55%-black scrim, elevated panel with 24px top
/// corners + 2px top border, sheetUp spring entrance, and a title row with a
/// close (X) button. Tapping the scrim closes.
class BottomSheetShell extends StatelessWidget {
  const BottomSheetShell({
    super.key,
    required this.title,
    required this.onClose,
    required this.children,
    this.titleStyleSize = 28,
    this.titleWidget,
  });

  final String title;
  final VoidCallback onClose;
  final List<Widget> children;
  final double titleStyleSize;

  /// Optional custom header (used by the win sheet's kicker + title).
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final reduce = reducedMotion(context);

    Widget panel = Container(
      width: double.infinity,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(34)),
        border: Border(top: BorderSide(color: t.border, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: titleWidget ??
                      Text(title,
                          style: Fonts.display(
                              size: titleStyleSize, color: t.text)),
                ),
                IconSquareButton(
                  icon: Icons.close,
                  semanticLabel: 'Close',
                  hoverColor: t.text,
                  onTap: onClose,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );

    if (!reduce) {
      panel = panel
          .animate()
          .slideY(
              begin: 0.25,
              end: 0,
              duration: Motion.sheet,
              curve: Motion.overshootSoft)
          .fadeIn(duration: Motion.standard);
    }

    // Wrapped in Positioned.fill by the app shell; must not return a Positioned.
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(onTap: () {}, child: panel),
        ),
      ],
    );
  }
}

/// A full-width primary (success-filled) button used across sheets.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.center = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return HoverBorder(
      onTap: onTap,
      builder: (context, hover) => Opacity(
        opacity: hover ? 0.9 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: t.success,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: center ? Alignment.center : Alignment.centerLeft,
          child: Text(label,
              style: Fonts.ui(
                  size: 15,
                  color: Colors.white,
                  weight: FontWeight.w700,
                  letterSpacing: 0.5,
                  height: 1)),
        ),
      ),
    );
  }
}

/// A full-width secondary (transparent, bordered) button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return HoverBorder(
      onTap: onTap,
      builder: (context, hover) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border.all(color: hover ? t.text : t.border, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: Fonts.ui(
                size: 13,
                color: t.text,
                weight: FontWeight.w700,
                letterSpacing: 0.5,
                height: 1)),
      ),
    );
  }
}
