import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Proximity heat bar: 8px tall pill, animated fill width, colored by [heat].
/// The juice layer adds a soft glow in the heat color and a gentle pulse when
/// the player is near the target — both suppressed under reduced motion.
class HeatBar extends StatefulWidget {
  const HeatBar({
    super.key,
    required this.percent,
    required this.heat,
  });

  final double percent;
  final Heat heat;

  @override
  State<HeatBar> createState() => _HeatBarState();
}

class _HeatBarState extends State<HeatBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _color(NumTokens t) => switch (widget.heat) {
        Heat.onTarget => t.success,
        Heat.near => t.progress,
        Heat.far => t.muted,
      };

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final color = _color(t);
    final reduce = reducedMotion(context);
    final pulsing = widget.heat == Heat.near && !reduce;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final glow = pulsing ? 0.25 + 0.35 * _pulse.value : 0.35;
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          clipBehavior: Clip.antiAlias,
          child: Align(
            alignment: Alignment.centerLeft,
            child: LayoutBuilder(
              builder: (context, box) => AnimatedContainer(
                duration: Motion.standard,
                curve: Motion.easeOut,
                width: box.maxWidth * widget.percent / 100,
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: reduce
                      ? null
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: glow),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                          ),
                        ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
