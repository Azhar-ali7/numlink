import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Animates a count-up/down between integer values. Under reduced motion it
/// snaps instantly. Uses tabular figures (from the supplied [style]) so the
/// width doesn't jitter while rolling.
class RollingNumber extends StatelessWidget {
  const RollingNumber(
    this.value, {
    super.key,
    required this.style,
    this.duration = Motion.standard,
  });

  final int value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: Motion.easeOut,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
