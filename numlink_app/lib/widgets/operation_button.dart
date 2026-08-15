import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/operation.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// One operation button in the pad: big op label, result preview line, and a
/// token-count pill top-right. Disabled (0.38 opacity) when solved, illegal,
/// or out of tokens. Shakes on an illegal tap.
class OperationButton extends StatelessWidget {
  const OperationButton({
    super.key,
    required this.op,
    required this.previewText,
    required this.remaining,
    required this.disabled,
    required this.shake,
    required this.onTap,
  });

  final Operation op;
  final String previewText;
  final int remaining;
  final bool disabled;
  final bool shake;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final tokenColor = remaining <= 0
        ? t.muted
        : (remaining == 1 ? t.progress : t.text);

    // Always delegate to the controller's apply(): an illegal/out-of-tokens
    // tap must still produce the shake + toast feedback (the button only looks
    // disabled). apply() itself no-ops once the puzzle is solved.
    final content = HoverBorder(
      onTap: onTap,
      builder: (context, hover) => Opacity(
        opacity: disabled ? 0.38 : 1,
        child: AnimatedContainer(
          duration: Motion.micro,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(
              color: hover && !disabled ? t.progress : t.border,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(op.label,
                      style: Fonts.mono(
                          size: 23, color: t.text, weight: FontWeight.w700)),
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
