import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'rolling_number.dart';

/// The connector + operation chip that sits above a node (edges after the
/// first node). When [dashed] it renders the dashed target placeholder edge.
class OpEdge extends StatelessWidget {
  const OpEdge({super.key, this.label, this.dashed = false});

  final String? label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final line = Container(
      width: 2,
      height: 12,
      color: dashed ? t.muted.withValues(alpha: 0.4) : t.border,
    );
    return Column(
      children: [
        line,
        if (dashed)
          _DashedPill(child: Text('?',
              style: Fonts.mono(size: 13, color: t.muted, weight: FontWeight.w700)))
        else
          Container(
            decoration: BoxDecoration(
              color: t.elevated,
              border: Border.all(color: t.border, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Text(label ?? '',
                style: Fonts.mono(
                    size: 13, color: t.text, weight: FontWeight.w700)),
          ),
        line,
      ],
    );
  }
}

class _DashedPill extends StatelessWidget {
  const _DashedPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return CustomPaint(
      painter: _DashedBorderPainter(t.muted, 999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: child,
      ),
    );
  }
}

/// Visual style bundle for a node.
class NodeStyle {
  const NodeStyle({
    required this.border,
    required this.bg,
    required this.numColor,
    this.badge,
    this.dashed = false,
  });

  final Color border;
  final Color bg;
  final Color numColor;
  final String? badge;
  final bool dashed;
}

class ChainNodeWidget extends StatelessWidget {
  const ChainNodeWidget({
    super.key,
    required this.value,
    required this.style,
    this.animateIn = false,
    this.rolling = false,
  });

  final int value;
  final NodeStyle style;
  final bool animateIn;
  final bool rolling;

  @override
  Widget build(BuildContext context) {
    final numStyle = Fonts.mono(size: 40, color: style.numColor, weight: FontWeight.w700);

    final inner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        rolling
            ? RollingNumber(value, style: numStyle)
            : Text('$value', style: numStyle),
        if (style.badge != null && style.badge!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            style.badge!,
            style: Fonts.ui(
              size: 10,
              color: style.border,
              weight: FontWeight.w700,
              letterSpacing: 1.5,
              height: 1,
            ),
          ),
        ],
      ],
    );

    final box = Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(18),
      ),
      foregroundDecoration: style.dashed
          ? _DashedBox(style.border)
          : BoxDecoration(
              border: Border.all(color: style.border, width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
      child: inner,
    );

    if (!animateIn || reducedMotion(context)) return box;
    return box
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: Motion.standard,
          curve: Motion.overshoot,
        )
        .fadeIn(duration: Motion.micro);
  }
}

/// A dashed rounded-rect border rendered as a [BoxDecoration]-like foreground.
class _DashedBox extends BoxDecoration {
  const _DashedBox(this.dashColor);
  final Color dashColor;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedBoxPainter(dashColor);
}

class _DashedBoxPainter extends BoxPainter {
  _DashedBoxPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & cfg.size!;
    final rrect =
        RRect.fromRectAndRadius(rect, const Radius.circular(18));
    _paintDashedRRect(canvas, rrect, color);
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter(this.color, this.radius);
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    _paintDashedRRect(canvas, rrect, color);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color;
}

void _paintDashedRRect(Canvas canvas, RRect rrect, Color color) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;
  final path = Path()..addRRect(rrect);
  const dash = 5.0, gap = 4.0;
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      canvas.drawPath(
        metric.extractPath(d, (d + dash).clamp(0, metric.length)),
        paint,
      );
      d += dash + gap;
    }
  }
}
