import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Fires a confetti burst whenever [pulse] increments (i.e. on each solve).
/// Sits above the game column but below the win sheet. No-op under reduced
/// motion.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.pulse});

  /// A monotonically increasing counter; a change triggers a burst.
  final int pulse;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  final ConfettiController _controller =
      ConfettiController(duration: Motion.celebrate);
  int _lastPulse = 0;

  @override
  void didUpdateWidget(covariant ConfettiOverlay old) {
    super.didUpdateWidget(old);
    if (widget.pulse != _lastPulse && widget.pulse > 0) {
      _lastPulse = widget.pulse;
      if (!reducedMotion(context)) _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _controller,
          blastDirection: math.pi / 2, // downward
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.0,
          numberOfParticles: 24,
          maxBlastForce: 22,
          minBlastForce: 8,
          gravity: 0.28,
          colors: [t.success, t.progress, t.text, NumTokens.altSuccessOrange],
        ),
      ),
    );
  }
}
