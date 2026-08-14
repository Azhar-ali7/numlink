import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// A small flickering flame that celebrates the player's streak. The flicker
/// is a subtle scale + opacity wobble; under reduced motion it holds steady.
/// Only shown when [streak] > 0.
class StreakFlame extends StatefulWidget {
  const StreakFlame({
    super.key,
    required this.streak,
    required this.color,
    this.size = 22,
  });

  final int streak;
  final Color color;
  final double size;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak <= 0) return const SizedBox.shrink();
    if (reducedMotion(context)) {
      return Icon(Icons.local_fire_department,
          color: widget.color, size: widget.size);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final wobble = math.sin(_c.value * math.pi);
        return Transform.scale(
          scale: 0.94 + 0.10 * wobble,
          child: Opacity(opacity: 0.85 + 0.15 * wobble, child: child),
        );
      },
      child: Icon(Icons.local_fire_department,
          color: widget.color, size: widget.size),
    );
  }
}
