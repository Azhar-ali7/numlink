import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// A small pill toast for transient messages (illegal taps, shuffle results).
class GameToast extends StatelessWidget {
  const GameToast({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.elevated,
        border: Border.all(color: t.progress, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: Fonts.ui(
              size: 13, color: t.text, weight: FontWeight.w500, height: 1.2)),
    );
    if (!reducedMotion(context)) {
      toast = toast.animate().fadeIn(duration: Motion.toast).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: Motion.toast);
    }
    return toast;
  }
}
