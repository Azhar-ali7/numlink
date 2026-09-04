import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// One stop on the tour: a widget to spotlight plus the copy explaining it.
class CoachStep {
  const CoachStep({this.target, required this.title, required this.body});

  /// The widget to punch out of the scrim. Null (or an unmounted key) shows the
  /// card alone, so a step whose element is missing on this board still reads.
  final GlobalKey? target;
  final String title, body;
}

/// A spotlight walkthrough: a dark scrim with a hole cut around each element in
/// turn, and a caption card beside it. Tapping anywhere advances.
///
/// Hand-rolled rather than a showcase package: it is a scrim, a
/// [Path.combine] and a card, and the app already owns the type scale it needs.
class CoachOverlay extends StatefulWidget {
  const CoachOverlay({super.key, required this.steps, required this.onDone});

  final List<CoachStep> steps;
  final VoidCallback onDone;

  @override
  State<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<CoachOverlay> {
  int _i = 0;

  /// Rects can only be read once everything (this overlay included) has been
  /// laid out, so the first frame paints nothing rather than a misplaced hole.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _next() {
    if (_i + 1 >= widget.steps.length) return widget.onDone();
    setState(() => _i++);
  }

  /// The step's target in *this overlay's* coordinates, or null when the target
  /// is absent (a board variant without that control) or not yet laid out.
  Rect? _spotlight(CoachStep step) {
    final target = step.target?.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (target is! RenderBox || self is! RenderBox || !target.hasSize) {
      return null;
    }
    final origin = self.globalToLocal(target.localToGlobal(Offset.zero));
    return (origin & target.size).inflate(8);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
    final t = NumTheme.of(context);
    final step = widget.steps[_i];
    final hole = _spotlight(step);
    // The overlay's own box, not the window: it sits inside a SafeArea, so the
    // window height would place the card a status bar too low.
    final self = context.findRenderObject() as RenderBox?;
    final size = self?.size ?? MediaQuery.sizeOf(context);
    // Card goes in whichever gap around the hole is roomier, and is padded
    // in from that edge — never positioned by its own (unknown) height, which
    // is how it ended up off-screen under a full-height board spotlight.
    final below = hole == null || size.height - hole.bottom >= hole.top;
    // Leave the card room to lay out even when the gap is thin — a spotlight
    // on the board itself leaves almost none, and a card squeezed below its
    // own height overflows, which also kills hit testing on its buttons. It
    // overlaps the hole in that case, which is the lesser evil.
    double pad(double v) => v.clamp(16.0, size.height - 260);

    // Tap-to-advance lives in four bands *around* the hole, not in one
    // full-screen catcher: the spotlighted control has to stay usable, or a
    // step that says "tap an operation" is a lie -- the tap died on the scrim.
    Widget band(double left, double top, double w, double h) => Positioned(
      left: left,
      top: top,
      width: max(0, w),
      height: max(0, h),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _next),
    );

    return Stack(
      children: [
        // IgnorePointer because CustomPainter.hitTest defaults to true, which
        // would put the scrim back in front of the hole.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ScrimPainter(hole: hole)),
          ),
        ),
        if (hole == null)
          band(0, 0, size.width, size.height)
        else ...[
          band(0, 0, size.width, hole.top),
          band(0, hole.bottom, size.width, size.height - hole.bottom),
          band(0, hole.top, hole.left, hole.height),
          band(hole.right, hole.top, size.width - hole.right, hole.height),
          Positioned.fromRect(
            rect: hole,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: t.progress, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: hole != null && below ? pad(hole.bottom + 14) : 16,
              bottom: hole != null && !below
                  ? pad(size.height - hole.top + 14)
                  : 16,
            ),
            child: Align(
              alignment: hole == null
                  ? Alignment.center
                  : (below ? Alignment.topCenter : Alignment.bottomCenter),
              child: _Card(step: step, state: this),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.step, required this.state});
  final CoachStep step;
  final _CoachOverlayState state;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final steps = state.widget.steps;
    final last = state._i == steps.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border, width: 2),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step.title,
            style: Fonts.display(size: 17, color: t.text, height: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: Fonts.ui(size: 13, color: t.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Container(
                  width: i == state._i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == state._i ? t.progress : t.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              if (!last)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: state.widget.onDone,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Skip',
                      style: Fonts.ui(
                        size: 13,
                        color: t.muted,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: state._next,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    last ? 'Got it' : 'Next',
                    style: Fonts.ui(
                      size: 13,
                      color: Colors.white,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fills the page except for [hole] — one path, evaluated as a difference.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.hole});
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final path = hole == null
        ? full
        : Path.combine(
            PathOperation.difference,
            full,
            Path()..addRRect(
              RRect.fromRectAndRadius(hole!, const Radius.circular(16)),
            ),
          );
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrimPainter old) => old.hole != hole;
}
