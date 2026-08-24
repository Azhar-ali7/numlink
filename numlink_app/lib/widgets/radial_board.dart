import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../game/tree_controller.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Ring spacing widens as the tree grows (prototype `ringGapFor`).
double ringGapFor(int n) =>
    n <= 4 ? 120 : (n <= 8 ? 136 : (n <= 13 ? 152 : 168));

/// Radial tree layout: start at the origin, children fan outward by angle with
/// each subtree's angular span weighted by its leaf count; depth sets the ring
/// radius. Pure function, ported from the prototype `layout()`.
Map<int, Offset> radialLayout(List<TreeNode> nodes) {
  final kids = <int, List<int>>{};
  for (final n in nodes) {
    if (n.parent != null) (kids[n.parent!] ??= []).add(n.id);
  }
  final leaves = <int, int>{};
  int countLeaves(int id) {
    final ks = kids[id] ?? const [];
    return leaves[id] =
        ks.isEmpty ? 1 : ks.fold(0, (s, k) => s + countLeaves(k));
  }

  countLeaves(0);
  final gap = ringGapFor(nodes.length);
  final pos = <int, Offset>{};
  void place(int id, int depth, double a0, double a1) {
    final angle = (a0 + a1) / 2;
    final r = depth * gap;
    pos[id] = Offset(cos(angle) * r, sin(angle) * r);
    final ks = kids[id] ?? const [];
    var cur = a0;
    for (final k in ks) {
      final span = (a1 - a0) * (leaves[k]! / leaves[id]!);
      place(k, depth + 1, cur, cur + span);
      cur += span;
    }
  }

  place(0, 0, -pi / 2, -pi / 2 + pi * 2);
  return pos;
}

/// Multi-target coloring (prototype `TARGET_HUES`). Themed success/progress
/// first, then three fixed brand accents.
List<Color> targetHues(NumTokens t) =>
    [t.success, t.progress, NumTokens.accent, NumTokens.hero, NumTokens.heroTwo];

/// The branching board: a radial tree of placed values with the outstanding
/// targets floated as ghost pills around the rim. Auto-fits via [FittedBox],
/// with [InteractiveViewer] pan/zoom on top and double-tap to refit.
class RadialBoard extends StatefulWidget {
  const RadialBoard({super.key});

  @override
  State<RadialBoard> createState() => _RadialBoardState();
}

class _RadialBoardState extends State<RadialBoard> {
  final _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<TreeController>();
    final t = NumTheme.of(context);
    final hues = targetHues(t);
    final targets = g.puzzle.targets;
    Color? hueOf(int v) {
      final i = targets.indexOf(v);
      return i >= 0 ? hues[i % hues.length] : null;
    }

    final pos = radialLayout(g.nodes);
    final gap = ringGapFor(g.nodes.length);
    final missing =
        targets.where((tt) => !g.nodes.any((n) => n.v == tt)).toList();

    // ghost targets spread on a rim outside the farthest node
    final maxR = g.nodes.isEmpty
        ? 0.0
        : g.nodes.map((n) => pos[n.id]!.distance).reduce(max);
    final ghostR = maxR + gap + missing.length * 26;
    final ghostPos = <int, Offset>{
      for (var i = 0; i < missing.length; i++)
        missing[i]: Offset(cos(i / max(1, missing.length) * pi * 2) * ghostR,
            sin(i / max(1, missing.length) * pi * 2) * ghostR)
    };

    // bounding box over every point → a canvas sized to fit with padding
    const pad = 60.0;
    final pts = [...pos.values, ...ghostPos.values, Offset.zero];
    final minX = pts.map((p) => p.dx).reduce(min) - pad;
    final maxX = pts.map((p) => p.dx).reduce(max) + pad;
    final minY = pts.map((p) => p.dy).reduce(min) - pad;
    final maxY = pts.map((p) => p.dy).reduce(max) + pad;
    final shift = Offset(-minX, -minY);
    final canvas = Size(maxX - minX, maxY - minY);

    Widget slot(Offset center, double w, double h, Widget child) => Positioned(
          left: center.dx + shift.dx - w / 2,
          top: center.dy + shift.dy - h / 2,
          width: w,
          height: h,
          child: Center(child: child),
        );

    final children = <Widget>[
      Positioned.fill(
        child: CustomPaint(
          painter: _EdgePainter(
            nodes: g.nodes,
            pos: pos,
            ghostPos: ghostPos,
            shift: shift,
            hueOf: hueOf,
            border: t.border,
            muted: t.muted,
          ),
        ),
      ),
      for (final v in missing)
        slot(ghostPos[v]!, 100, 64,
            _GhostPill(value: v, hue: hueOf(v) ?? t.muted)),
      for (final n in g.nodes)
        slot(
          pos[n.id]!,
          100,
          92,
          _NodeChip(
            node: n,
            hue: hueOf(n.v),
            isStart: n.parent == null,
            isSelected: n.id == g.sel,
            onTap: () => g.select(n.id),
          ),
        ),
    ];

    return InteractiveViewer(
      transformationController: _tc,
      minScale: 0.4,
      maxScale: 3,
      boundaryMargin: const EdgeInsets.all(400),
      child: GestureDetector(
        onDoubleTap: () => _tc.value = Matrix4.identity(),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: Stack(clipBehavior: Clip.none, children: children),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.nodes,
    required this.pos,
    required this.ghostPos,
    required this.shift,
    required this.hueOf,
    required this.border,
    required this.muted,
  });

  final List<TreeNode> nodes;
  final Map<int, Offset> pos;
  final Map<int, Offset> ghostPos;
  final Offset shift;
  final Color? Function(int) hueOf;
  final Color border, muted;

  /// Draws a dashed segment from a→b (already shifted into canvas space).
  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint,
      {double dash = 7, double gap = 6}) {
    final dir = b - a;
    final len = dir.distance;
    if (len == 0) return;
    final u = dir / len;
    var d = 0.0;
    while (d < len) {
      final s = a + u * d;
      final e = a + u * min(d + dash, len);
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // dashed ghost connectors: start (node 0) → each outstanding target
    final origin = (pos[0] ?? Offset.zero) + shift;
    ghostPos.forEach((v, p) {
      final b = p + shift;
      final dir = b - origin;
      final len = dir.distance;
      if (len == 0) return;
      final u = dir / len;
      _dashed(
        canvas,
        origin + u * 34,
        b - u * 34,
        Paint()
          ..color = (hueOf(v) ?? border).withValues(alpha: 0.6)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    });
    for (final n in nodes) {
      if (n.parent == null) continue;
      final a = pos[n.parent!]! + shift;
      final b = pos[n.id]! + shift;
      final dir = b - a;
      final len = dir.distance;
      if (len == 0) continue;
      final u = dir / len;
      final p1 = a + u * 34; // trim to node edges
      final p2 = b - u * 34;
      final color = hueOf(n.v) ?? border;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      if (n.opLabel != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: n.opLabel,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final mid = (a + b) / 2;
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.nodes != nodes ||
      old.pos != pos ||
      old.ghostPos != ghostPos ||
      old.shift != shift;
}

class _NodeChip extends StatelessWidget {
  const _NodeChip({
    required this.node,
    required this.hue,
    required this.isStart,
    required this.isSelected,
    required this.onTap,
  });

  final TreeNode node;
  final Color? hue;
  final bool isStart, isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final isTarget = hue != null;
    final Color ring = isStart
        ? NumTokens.hero
        : (isTarget ? hue! : (isSelected ? t.progress : t.border));
    final Color fill = isStart
        ? NumTokens.hero
        : (isTarget ? hue! : (isSelected ? tint(t.progress, 0.12) : t.elevated));
    final Color numColor =
        (isStart || isTarget) ? Colors.white : t.text;
    final badge = isTarget
        ? 'TARGET ✓'
        : (isStart ? 'START' : (isSelected ? 'BUILDING' : ''));

    final chip = GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: isStart ? 64 : 56),
        width: isStart ? 64 : null,
        height: isStart ? 64 : null,
        padding: isStart
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: ring, width: isSelected ? 2.6 : 2),
          borderRadius: BorderRadius.circular(isStart ? 999 : 18),
          boxShadow: isStart
              ? [
                  BoxShadow(
                      color: tint(NumTokens.hero, 0.28),
                      blurRadius: 0,
                      spreadRadius: 4),
                ]
              : isSelected
                  ? [BoxShadow(color: tint(t.progress, 0.30), blurRadius: 12)]
                  : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${node.v}',
                style: Fonts.mono(
                    size: isTarget ? 24 : (isStart ? 21 : 20),
                    color: numColor,
                    weight: FontWeight.w700,
                    height: 1)),
            if (badge.isNotEmpty)
              Text(badge,
                  style: Fonts.ui(
                      size: 8,
                      color: (isTarget || isStart) ? Colors.white : ring,
                      weight: FontWeight.w800,
                      letterSpacing: 1,
                      height: 1.4)),
          ],
        ),
      ),
    );

    // arithmetic springs in; alchemy (unary transforms) pops with a twist.
    if (node.parent == null || reducedMotion(context)) return chip;
    final alchemy = const {'Σ', '↺', 'x²', '√'}.contains(node.opLabel);
    return chip
        .animate()
        .scale(
          begin: Offset(alchemy ? 0.5 : 0.7, alchemy ? 0.5 : 0.7),
          end: const Offset(1, 1),
          duration: alchemy ? 520.ms : 240.ms,
          curve: Motion.overshoot,
        )
        .fadeIn(duration: 200.ms);
  }
}

class _GhostPill extends StatelessWidget {
  const _GhostPill({required this.value, required this.hue});
  final int value;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    Widget pill = CustomPaint(
      painter: _DashedRRectPainter(color: hue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: tint(hue, 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value',
                style: Fonts.mono(
                    size: 20, color: hue, weight: FontWeight.w700, height: 1)),
            Text('TARGET',
                style: Fonts.ui(
                    size: 8,
                    color: hue,
                    weight: FontWeight.w800,
                    letterSpacing: 1,
                    height: 1.5)),
          ],
        ),
      ),
    );
    if (!reducedMotion(context)) {
      pill = pill
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.06, 1.06),
              duration: 1400.ms,
              curve: Curves.easeInOut);
    }
    return pill;
  }
}

/// Dashed rounded-rectangle border drawn around the painter's child bounds.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dash = 6.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
            metric.extractPath(d, min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}
