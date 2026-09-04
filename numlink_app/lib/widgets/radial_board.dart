import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../game/tree_controller.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Ring spacing widens as the tree grows (prototype `ringGapFor`, scaled up).
///
/// The prototype's gaps (120/136/152/168) leave no room for the op-label pill:
/// between the parent chip's edge and the child box's near corner a diagonal
/// edge only clears ~55–61px, and the label sits at the midpoint (60) — so it
/// grazed the child box. These gaps give the pill ~16px of slack either side.
/// The board auto-fits, so a wider ring just scales down, it never clips.
double ringGapFor(int n) =>
    n <= 4 ? 150 : (n <= 8 ? 170 : (n <= 13 ? 190 : 210));

/// Radial tree layout: start at the origin; children fan outward within a cone
/// CENTRED on their parent's outward direction, weighted by each subtree's leaf
/// count, and the cone narrows each level so the tree keeps growing downward
/// instead of wrapping to the sides. Depth sets the ring radius. Pure function.
///
/// (The prototype `layout()` fanned the full circle from a centred start — fine
/// for a spider, but here START sits at the top and the tree grows *down*, so a
/// branch deep in a chain must stay under its parent rather than shoot out to
/// START's height with edges crossing the board.)
Map<int, Offset> radialLayout(List<TreeNode> nodes) {
  final kids = <int, List<int>>{};
  for (final n in nodes) {
    if (n.parent != null) (kids[n.parent!] ??= []).add(n.id);
  }
  final leaves = <int, int>{};
  int countLeaves(int id) {
    final ks = kids[id] ?? const [];
    return leaves[id] = ks.isEmpty
        ? 1
        : ks.fold(0, (s, k) => s + countLeaves(k));
  }

  countLeaves(0);
  final gap = ringGapFor(nodes.length);
  final pos = <int, Offset>{};
  // ponytail: fixed 0.6 narrowing + 150° base cone. A very wide AND deep branch
  // could still crowd; revisit only if a real puzzle actually produces one
  // (branchMax caps depth, and ghostLayout has its own de-overlap pass).
  void place(int id, int depth, double center, double span) {
    final r = depth * gap;
    pos[id] = Offset(cos(center) * r, sin(center) * r);
    final ks = kids[id] ?? const [];
    if (ks.isEmpty) return;
    var cur = center - span / 2;
    for (final k in ks) {
      final frac = leaves[k]! / leaves[id]!;
      place(k, depth + 1, cur + span * frac / 2, span * 0.6);
      cur += span * frac;
    }
  }

  // Root at the centre; children fan downward (+y = π/2) within a 150° cone.
  place(0, 0, pi / 2, pi * 5 / 6);
  return pos;
}

/// Places the outstanding [missing] target values as ghost pills around the
/// placed tree. Each ghost anchors to the node nearest in value and fans off
/// that node's outward ray — but skips the centre slot when a real child arm
/// already occupies it (else it lands right on that child). A final de-overlap
/// pass slides any ghost still within [minDist] of a node or an earlier ghost
/// further out along its ray until it clears, so two markers never stack.
///
/// Returns each target's placed offset plus the offset of the anchor node its
/// dashed connector should start from. Pure — unit-testable without a widget.
({Map<int, Offset> pos, Map<int, Offset> anchor}) ghostLayout({
  required List<int> missing,
  required List<TreeNode> nodes,
  required Map<int, Offset> nodePos,
  required double gap,
  double minDist = 96,
}) {
  // A ghost is a tip you'd build *toward*, so anchor it to a LEAF (a real arm
  // end), never the trunk — anchoring to an interior node draws the dashed
  // connector back across that node's own children (the crossing lines the
  // player saw when START, the trunk, was the nearest value to a target).
  final parents = {
    for (final n in nodes)
      if (n.parent != null) n.parent!,
  };
  final candidates = nodes.where((n) => !parents.contains(n.id)).toList();
  final tips = candidates.isEmpty ? nodes : candidates; // START alone is a leaf
  final anchorOf = <int, TreeNode>{}; // target value → anchor node (a tip)
  for (final tv in missing) {
    var best = tips.first;
    var bestD = (best.v - tv).abs();
    for (final n in tips) {
      final d = (n.v - tv).abs();
      if (d < bestD) {
        bestD = d;
        best = n;
      }
    }
    anchorOf[tv] = best;
  }
  final groupCount = <int, int>{};
  for (final tv in missing) {
    groupCount[anchorOf[tv]!.id] = (groupCount[anchorOf[tv]!.id] ?? 0) + 1;
  }
  // Anchors that already carry a real child have their outward ray occupied by
  // that arm; ghosts hanging off them must skip the centre slot or they land
  // right on top of the child node (nodes are ~100px wide but a ring is only
  // ~120px out, so same-angle/same-radius = overlap).
  final anchorHasChild = {
    for (final n in nodes)
      if (n.parent != null) n.parent!,
  };
  // Recover each node's polar angle from its placed offset; the start sits at
  // the origin, where the layout points straight down (+y = down).
  double angleOf(Offset p) => p == Offset.zero ? pi / 2 : atan2(p.dy, p.dx);
  // Fan slot for the idx-th of [count] ghosts on one anchor: centred when the
  // arm is open (0, ±½, ±1…), but pushed off the centre ray to alternating
  // sides (+1, −1, +2…) when a real child already occupies it.
  double slotOffset(int idx, int count, bool blocked) {
    if (!blocked) return idx - (count - 1) / 2;
    final step = idx ~/ 2 + 1;
    return idx.isEven ? step.toDouble() : -step.toDouble();
  }

  // Every placed node is a fixed obstacle; ghosts are added as they're placed.
  final obstacles = [for (final n in nodes) nodePos[n.id]!];
  final seen = <int, int>{};
  final ghostPos = <int, Offset>{};
  for (final tv in missing) {
    final aId = anchorOf[tv]!.id;
    final ap = nodePos[aId]!;
    final count = groupCount[aId]!;
    final idx = seen[aId] ?? 0;
    seen[aId] = idx + 1;
    var radius = ap.distance + gap + max(0, count - 2) * 26;
    final spacing = max(0.36, 104 / max(radius, 60));
    final angle =
        angleOf(ap) +
        slotOffset(idx, count, anchorHasChild.contains(aId)) * spacing;
    var p = Offset(cos(angle) * radius, sin(angle) * radius);
    // De-overlap safety net: if the ghost still lands on a node or an earlier
    // ghost, slide it outward along its own ray until it clears (bounded).
    for (
      var guard = 0;
      guard < 64 && obstacles.any((q) => (q - p).distance < minDist);
      guard++
    ) {
      radius += minDist * 0.5;
      p = Offset(cos(angle) * radius, sin(angle) * radius);
    }
    ghostPos[tv] = p;
    obstacles.add(p);
  }
  return (
    pos: ghostPos,
    anchor: {for (final tv in missing) tv: nodePos[anchorOf[tv]!.id]!},
  );
}

/// Multi-target coloring (prototype `TARGET_HUES`). Themed success/progress
/// first, then three fixed brand accents.
List<Color> targetHues(NumTokens t) => [
  t.success,
  t.progress,
  t.accent,
  t.hero,
  t.heroTwo,
];

/// The branching board: a radial tree of placed values with the outstanding
/// targets floated as ghost pills around the rim. Auto-fits by easing a
/// [Matrix4] fit transform on each move (so the board zooms/pans smoothly
/// instead of jumping), with [InteractiveViewer] pan/zoom on top and
/// double-tap to reset.
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
    final missing = targets
        .where((tt) => !g.nodes.any((n) => n.v == tt))
        .toList();

    // Ghost targets anchor to the existing node nearest in value, then fan out
    // around that node's own angle past the outer ring — so they trail the arm
    // they'd extend rather than scattering on a full circle (prototype math).
    final ghosts = ghostLayout(
      missing: missing,
      nodes: g.nodes,
      nodePos: pos,
      gap: gap,
    );
    final ghostPos = ghosts.pos;
    final ghostAnchor = ghosts.anchor;

    // Tight bounding box over every point → a canvas sized exactly to the
    // content (no wasted space, nothing hidden). The fit transform that centres
    // and scales this into the viewport is computed and *animated* below, so the
    // board eases to its new fit on each move instead of snapping/jumping.
    const pad = 60.0;
    final pts = [...pos.values, ...ghostPos.values];
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
            ghostAnchor: ghostAnchor,
            shift: shift,
            hueOf: hueOf,
            border: t.border,
            muted: t.muted,
          ),
        ),
      ),
      for (final n in g.nodes)
        if (n.parent != null && n.opLabel != null)
          slot(
            (pos[n.parent!]! + pos[n.id]!) / 2,
            90,
            30,
            _EdgeLabel(text: n.opLabel!, hue: hueOf(n.v) ?? t.border),
          ),
      for (final v in missing)
        slot(
          ghostPos[v]!,
          100,
          64,
          _GhostPill(value: v, hue: hueOf(v) ?? t.muted),
        ),
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

    final board = SizedBox(
      width: canvas.width,
      height: canvas.height,
      child: Stack(clipBehavior: Clip.none, children: children),
    );

    return InteractiveViewer(
      transformationController: _tc,
      minScale: 0.4,
      maxScale: 3,
      boundaryMargin: const EdgeInsets.all(400),
      // No double-tap-to-reset: an ancestor double-tap recognizer holds the
      // gesture arena for kDoubleTapTimeout, so every node tap under it only
      // fired ~300ms late and the board felt unresponsive. Pinch/pan is bounded
      // by boundaryMargin, and each move re-fits, so the reset earned little.
      // Auto-fit that EASES. Each move we recompute the transform that scales
      // the tight canvas into the viewport and centres it, then animate the
      // Matrix4 to it — so the board smoothly zooms/pans to its new fit
      // instead of the abrupt jump ("expanding randomly") a plain FittedBox
      // gave. InteractiveViewer still layers manual pan/zoom on top.
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = min(
            box.maxWidth / canvas.width,
            box.maxHeight / canvas.height,
          );
          final fit = Matrix4.identity()
            ..translateByDouble(
              (box.maxWidth - canvas.width * scale) / 2,
              (box.maxHeight - canvas.height * scale) / 2,
              0,
              1,
            )
            ..scaleByDouble(scale, scale, 1, 1);
          // The Transform paints the board at the fit position/scale, but a
          // raw Transform reports its child's UNSCALED size to layout (unlike
          // FittedBox) — so it needs a viewport-sized box around it. NOT a
          // Stack: a Stack loosens a non-positioned child to the viewport,
          // which silently clamped the board once the tree outgrew the
          // screen. It still painted right (Clip.none), but every chip
          // outside the clamped rect failed hit testing — RenderBox.hitTest
          // gates on the clamped size — so far nodes stopped selecting.
          // OverflowBox lets the board lay out at its full canvas size;
          // topLeft because the matrix already does the centring.
          Widget wrap(Matrix4 m) => SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: OverflowBox(
              alignment: Alignment.topLeft,
              // min 0 as well: the incoming constraints are tight, so
              // overriding only the max leaves min > max on a canvas
              // smaller than the viewport.
              minWidth: 0,
              minHeight: 0,
              maxWidth: canvas.width,
              maxHeight: canvas.height,
              child: Transform(transform: m, child: board),
            ),
          );
          if (reducedMotion(context)) return wrap(fit);
          return TweenAnimationBuilder<Matrix4>(
            tween: Matrix4Tween(end: fit),
            duration: Motion.standard,
            curve: Curves.easeOutCubic,
            builder: (context, m, child) => wrap(m),
          );
        },
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.nodes,
    required this.pos,
    required this.ghostPos,
    required this.ghostAnchor,
    required this.shift,
    required this.hueOf,
    required this.border,
    required this.muted,
  });

  final List<TreeNode> nodes;
  final Map<int, Offset> pos;
  final Map<int, Offset> ghostPos;
  final Map<int, Offset> ghostAnchor;
  final Offset shift;
  final Color? Function(int) hueOf;
  final Color border, muted;

  /// Draws a dashed segment from a→b (already shifted into canvas space).
  void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double dash = 7,
    double gap = 6,
  }) {
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
    // dashed ghost connectors: each outstanding target trails its anchor node
    ghostPos.forEach((v, p) {
      final origin = (ghostAnchor[v] ?? pos[0] ?? Offset.zero) + shift;
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
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      // Op labels are rendered as positioned pill widgets (see _EdgeLabel in
      // RadialBoard.children), matching the handoff's bordered pill.
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.nodes != nodes ||
      old.pos != pos ||
      old.ghostPos != ghostPos ||
      old.ghostAnchor != ghostAnchor ||
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
        ? t.hero
        : (isTarget ? hue! : (isSelected ? t.progress : t.border));
    // The selected node keeps its sibling fill (a plain elevated square); it's
    // marked current by the ring + glow below, not by a loud amber block.
    final Color fill = isStart ? t.hero : (isTarget ? hue! : t.elevated);
    final Color numColor = (isStart || isTarget) ? Colors.white : t.text;
    final badge = isTarget
        ? 'TARGET ✓'
        : (isStart ? 'START' : (isSelected ? 'BUILDING' : ''));
    // Plain in-progress nodes (not start, not a hit target) are the working
    // scratchpad — kept tighter than the emphasised start/target chips.
    final isPlain = !isStart && !isTarget;

    final chip = GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          minWidth: isStart ? 64 : (isPlain ? 38 : 54),
        ),
        width: isStart ? 64 : null,
        height: isStart ? 64 : null,
        padding: isStart
            ? EdgeInsets.zero
            : (isPlain
                  ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4)
                  : const EdgeInsets.symmetric(horizontal: 11, vertical: 7)),
        // Only START gets an alignment: it has a fixed 64×64 box that needs its
        // content centred. On the others a non-null alignment makes Container
        // expand to fill its loose constraints — i.e. the whole 100×92 slot —
        // so every chip came out the same size and a target could never read as
        // bigger than the scratchpad node feeding it. Without it they
        // shrink-wrap, and the font/padding scale below does the talking.
        alignment: isStart ? Alignment.center : null,
        decoration: BoxDecoration(
          // Plain nodes are a working scratchpad, not a prize: a soft
          // white→cream wash (the theme's own elevated→surface pair) keeps them
          // quieter than the flat, saturated target fills.
          color: isPlain ? null : fill,
          gradient: isPlain
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [t.elevated, t.surface],
                )
              : null,
          border: Border.all(color: ring, width: isPlain ? 2 : 3),
          // One radius for every non-START node, per the handoff
          // (`radius: isStart ? 999 : 24`) — and the same 24 the ghost pills
          // use, so START is the only circle and everything else reads as one
          // rounded family instead of BUILDING looking square next to them.
          borderRadius: BorderRadius.circular(isStart ? 999 : 24),
          boxShadow: isStart
              ? [
                  BoxShadow(
                    color: tint(t.hero, 0.28),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                ]
              : isSelected
              ? [
                  BoxShadow(
                    color: tint(isTarget ? hue! : t.progress, 0.30),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${node.v}',
              style: Fonts.numeric(
                size: isStart ? 21 : (isPlain ? 14 : 19),
                color: numColor,
                weight: FontWeight.w800,
                height: 1,
              ),
            ),
            if (badge.isNotEmpty)
              Text(
                badge,
                style: Fonts.ui(
                  size: isPlain ? 7 : 9,
                  color: (isTarget || isStart) ? Colors.white : ring,
                  weight: FontWeight.w800,
                  letterSpacing: isPlain ? 0.4 : 1.3,
                  height: 1.4,
                ),
              ),
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

/// An op label riding the middle of an edge — a bordered pill (handoff
/// `edgeLabels`). Pops in with the node it belongs to.
class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({required this.text, required this.hue});
  final String text;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: t.elevated,
        border: Border.all(color: hue, width: 2),
        borderRadius: BorderRadius.circular(999),
        boxShadow: t.cardShadow,
      ),
      child: Text(
        text,
        style: Fonts.numeric(size: 12, color: hue, weight: FontWeight.w800),
      ),
    );
    if (reducedMotion(context)) return pill;
    return pill
        .animate()
        .fadeIn(duration: 120.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 200.ms,
          curve: Motion.overshoot,
        );
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
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: tint(hue, 0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: Fonts.numeric(
                size: 24,
                color: hue,
                weight: FontWeight.w800,
                height: 1,
              ),
            ),
            Text(
              'TARGET',
              style: Fonts.ui(
                size: 9,
                color: hue,
                weight: FontWeight.w800,
                letterSpacing: 1.3,
                height: 1.5,
              ),
            ),
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
            curve: Curves.easeInOut,
          );
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
      const Radius.circular(24),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const dash = 6.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}
