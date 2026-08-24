import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/operation.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Per-operator brand hue (prototype `hueMap`): multiplicative indigo, additive
/// teal, subtract orange, divide pink, modulo amber, Σ gold, rest muted.
Color opHue(Operation op, NumTokens t) => switch (op.symbol) {
      '×' => NumTokens.hero,
      '÷' => NumTokens.accent,
      '+' => t.success,
      '−' => NumTokens.accentOrange,
      '%' => t.progress,
      'Σ' => NumTokens.star,
      _ => t.muted,
    };

/// One operation button in the pad: big colored op glyph, an optional result
/// preview line, and a token-count pill top-right. Disabled (0.38 opacity) when
/// solved, illegal, or out of tokens. Shakes on an illegal tap.
class OperationButton extends StatelessWidget {
  const OperationButton({
    super.key,
    required this.op,
    required this.previewText,
    required this.remaining,
    required this.disabled,
    required this.shake,
    required this.onTap,
    this.highlighted = false,
  });

  final Operation op;
  final String previewText;
  final int remaining;
  final bool disabled;
  final bool shake;
  final VoidCallback onTap;

  /// A hint is pointing at this op — draw an emphasized border.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final tokenColor = remaining <= 0
        ? t.muted
        : (remaining == 1 ? t.progress : t.text);
    final hue = disabled ? t.muted : opHue(op, t);
    final borderColor = highlighted || (shake)
        ? t.progress
        : Color.lerp(t.border, hue, 0.5)!;

    // Always delegate to the controller's apply(): an illegal/out-of-tokens
    // tap must still produce the shake + toast feedback (the button only looks
    // disabled). apply() itself no-ops once the puzzle is solved.
    final content = HoverBorder(
      onTap: onTap,
      builder: (context, hover) => Opacity(
        opacity: disabled ? 0.38 : 1,
        child: AnimatedContainer(
          duration: Motion.micro,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            // Colored per-operator panel: faint hue fill + soft hued border.
            color: disabled ? tint(t.text, 0.04) : tint(hue, 0.09),
            border: Border.all(
              color: (hover && !disabled) ? hue : borderColor,
              width: 1.4, // <2 keeps clear of the old 1.6px overflow ceiling
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                        color: t.progress.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 0)
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(op.label,
                      style: Fonts.mono(
                          size: 26, color: hue, weight: FontWeight.w800)),
                  if (previewText.isNotEmpty)
                    Text(previewText,
                        style: Fonts.mono(size: 12, color: t.muted)),
                ],
              ),
              Positioned(
                top: -3,
                right: -3,
                child: Text('$remaining×',
                    style: Fonts.mono(
                        size: 11, color: tokenColor, weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );

    // Shake on illegal tap; suppressed under reduced motion.
    if (shake && !reducedMotion(context)) {
      return content
          .animate()
          .shakeX(duration: Motion.shake, hz: 6, amount: 5);
    }
    return content;
  }
}
