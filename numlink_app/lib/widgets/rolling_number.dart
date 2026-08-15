import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Animates a count-up/down between integer values. Under reduced motion it
/// snaps instantly. Uses tabular figures (from the supplied [style]) so the
/// width doesn't jitter while rolling.
///
/// Tracks the previous value so the tween runs previous→current on every
/// change (the old version had begin == end, so it never moved). A [ValueKey]
/// on the value restarts the builder from scratch each change.
class RollingNumber extends StatefulWidget {
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
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber> {
  late int _prev = widget.value;

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _prev = old.value;
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) {
      return Text('${widget.value}', style: widget.style);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.value),
      tween: Tween(begin: _prev.toDouble(), end: widget.value.toDouble()),
      duration: widget.duration,
      curve: Motion.easeOut,
      builder: (context, v, _) => Text('${v.round()}', style: widget.style),
    );
  }
}
