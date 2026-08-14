import 'package:flutter/material.dart';

/// Motion budget from the handoff research:
/// 120ms micro / 260ms standard / 480ms celebrate.
/// Default ease-out cubic(0.4,0,0.2,1); gentle overshoot spring only for
/// node pop-in and sheet entrances. All motion is disabled under
/// `prefers-reduced-motion` (see [reducedMotion]).
class Motion {
  const Motion._();

  static const Duration micro = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration celebrate = Duration(milliseconds: 480);
  static const Duration toast = Duration(milliseconds: 160);
  static const Duration shake = Duration(milliseconds: 340);
  static const Duration sheet = Duration(milliseconds: 280);

  /// Default ease-out.
  static const Curve easeOut = Cubic(0.4, 0, 0.2, 1);

  /// Gentle overshoot for pop-in.
  static const Curve overshoot = Cubic(0.34, 1.4, 0.64, 1);

  /// Slightly softer overshoot for sheet entrances.
  static const Curve overshootSoft = Cubic(0.34, 1.2, 0.64, 1);
}

/// True when the OS requests reduced motion — in that case animations should
/// degrade to instant. Mirrors the handoff's
/// `@media (prefers-reduced-motion: reduce) { * { animation: none } }`.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
