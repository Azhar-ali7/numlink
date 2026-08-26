import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../game/campaign.dart';
import '../game/game_mode.dart';
import '../game/tree_generator.dart';
import '../game/game_controller.dart';
import '../screens/tree_game_page.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// The campaign roadmap, rebuilt to the design handoff's cartoon "board-game
/// trail": a full-screen page with a header (back · Campaign · current tier ·
/// ★-total badge), then Level 1 at the top and a chunky teal ribbon zig-zagging
/// down through numbered nodes, a colored star row over each cleared level,
/// chapter bands at tier boundaries, and the next playable level marked with a
/// bouncing PLAY cue. The future trail is dotted; locked nodes are dimmed.
class CampaignPage extends StatelessWidget {
  const CampaignPage({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final starColors = [t.star, t.accent, t.hero];
    final stats = g.stats;
    final count = g.campaignCount;
    final maxStars = count * 3;

    // Current chapter = tier of the next playable (unlocked, uncleared) level,
    // falling back to the last tier once everything is cleared.
    var tier = kCampaign.first.tier;
    for (var i = 0; i < count; i++) {
      if (stats.levelUnlocked(i + 1) && stats.levelStars[i + 1] == null) {
        tier = kCampaign[i].tier;
        break;
      }
      tier = kCampaign[i].tier;
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: back button + title/tier + ★-total badge.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconSquareButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'Back',
                    hoverColor: t.text,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Campaign',
                            style: Fonts.display(size: 28, color: t.text)),
                        const SizedBox(height: 2),
                        Text(_Trail._chapter(tier),
                            style: Fonts.ui(
                                size: 11,
                                color: t.muted,
                                weight: FontWeight.w800,
                                letterSpacing: 1,
                                height: 1)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tint(t.progress, 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tint(t.progress, 0.4), width: 2),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, size: 16, color: t.progress),
                      const SizedBox(width: 4),
                      Text('${stats.campaignStars}',
                          style: Fonts.numeric(
                              size: 14, color: t.text, weight: FontWeight.w700)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Progress header: cleared count + star total + bar.
              Row(
                children: [
                  Text('${stats.campaignCleared} OF $count CLEARED',
                      style: Fonts.ui(
                          size: 12,
                          color: t.muted,
                          weight: FontWeight.w800,
                          letterSpacing: 1,
                          height: 1)),
                  const Spacer(),
                  Icon(Icons.star_rounded, size: 16, color: t.progress),
                  const SizedBox(width: 4),
                  Text('${stats.campaignStars} / $maxStars',
                      style: Fonts.numeric(
                          size: 13, color: t.text, weight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: maxStars == 0 ? 0 : stats.campaignStars / maxStars,
                  minHeight: 8,
                  backgroundColor: tint(t.text, 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(t.success),
                ),
              ),
              const SizedBox(height: 20),
              _Trail(
                g: g,
                starColors: starColors,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrollable trail body: computes zig-zag node centers, paints the ribbon
/// behind them, and stacks nodes + chapter bands on top.
class _Trail extends StatelessWidget {
  const _Trail({required this.g, required this.starColors});

  final GameController g;
  final List<Color> starColors;

  static const _rowH = 118.0;
  static const _nodeR = 30.0;
  static const _top = 10.0;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final stats = g.stats;
    final count = g.campaignCount;

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        double cx(int i) => width * (i.isEven ? 0.30 : 0.70);
        double cy(int i) => _top + i * _rowH + _rowH / 2;
        final centers = [for (var i = 0; i < count; i++) Offset(cx(i), cy(i))];
        final unlocked = [
          for (var i = 0; i < count; i++) stats.levelUnlocked(i + 1)
        ];
        final height = _top + count * _rowH + 30;

        final children = <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: _TrailPainter(
                centers: centers,
                unlocked: unlocked,
                reached: t.success,
                locked: tint(t.text, 0.18),
              ),
            ),
          ),
        ];

        // Chapter bands at each tier boundary (level 1, 7, 15).
        for (var i = 0; i < count; i++) {
          final isFirst = i == 0 || kCampaign[i].tier != kCampaign[i - 1].tier;
          if (!isFirst) continue;
          children.add(Positioned(
            left: 0,
            right: 0,
            top: cy(i) - _rowH / 2 - 4,
            child: Center(child: _ChapterBand(label: _chapter(kCampaign[i].tier))),
          ));
        }

        // Nodes.
        for (var i = 0; i < count; i++) {
          final stars = stats.levelStars[i + 1];
          children.add(Positioned(
            left: centers[i].dx - 60,
            top: centers[i].dy - _nodeR - 30,
            width: 120,
            child: _TrailNode(
              def: kCampaign[i],
              stars: stars,
              unlocked: unlocked[i],
              starColors: starColors,
              onTap: () => _openBranchingLevel(context, g, kCampaign[i]),
            ),
          ));
        }

        return SizedBox(height: height, child: Stack(children: children));
      },
    );
  }

  static String _chapter(Difficulty tier) => switch (tier) {
        Difficulty.kids => 'FIRST STEPS',
        Difficulty.easy => 'FOUNDATIONS',
        Difficulty.medium => 'ADVANCED',
        Difficulty.hard => 'EXPERT',
      };
}

/// Paints the ribbon: a chunky rounded teal stroke through reached segments and
/// a dotted trail through the locked ones.
class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.centers,
    required this.unlocked,
    required this.reached,
    required this.locked,
  });

  final List<Offset> centers;
  final List<bool> unlocked;
  final Color reached;
  final Color locked;

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = reached
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()
      ..color = locked
      ..style = PaintingStyle.fill;

    for (var i = 1; i < centers.length; i++) {
      final p0 = centers[i - 1];
      final p1 = centers[i];
      final midY = (p0.dy + p1.dy) / 2;
      final seg = Path()
        ..moveTo(p0.dx, p0.dy)
        ..cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
      if (unlocked[i]) {
        canvas.drawPath(seg, solid);
      } else {
        for (final m in seg.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 15) {
            final pos = m.getTangentForOffset(d)?.position;
            if (pos != null) canvas.drawCircle(pos, 3.5, dot);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.centers != centers || old.unlocked != unlocked;
}

/// A rounded chapter pill (FOUNDATIONS / ADVANCED / EXPERT).
class _ChapterBand extends StatelessWidget {
  const _ChapterBand({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border, width: 2),
      ),
      child: Text(label,
          style: Fonts.ui(
              size: 12,
              color: t.text,
              weight: FontWeight.w800,
              letterSpacing: 1,
              height: 1)),
    );
  }
}

/// One node on the trail: a star row (cleared), the numbered circle, and a PLAY
/// cue (current) or lock (future).
class _TrailNode extends StatelessWidget {
  const _TrailNode({
    required this.def,
    required this.stars,
    required this.unlocked,
    required this.starColors,
    required this.onTap,
  });

  final LevelDef def;
  final int? stars;
  final bool unlocked;
  final List<Color> starColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final cleared = stars != null;
    final current = unlocked && !cleared;
    final on = !reducedMotion(context);

    final circleColor = cleared
        ? t.success
        : current
            ? t.progress
            : t.surface;
    final numberColor = cleared
        ? Colors.white
        : current
            ? const Color(0xFF2B2622)
            : t.muted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Star row over the node (reserve height so anchoring stays exact).
        SizedBox(
          height: 22,
          child: cleared
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(
                        i < stars! ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 20,
                        color: i < stars! ? starColors[i] : t.border,
                      ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: unlocked ? onTap : null,
          // Current node breathes so the eye lands on where to play next
          // (handoff `glow`), gated behind reduced-motion.
          child: _pulse(
            current && on,
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: current
                      ? t.progress
                      : cleared
                          ? t.success
                          : t.border,
                  width: current ? 3 : 2,
                ),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: (cleared ? t.success : t.progress)
                              .withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: -3,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: unlocked
                  ? Text('${def.no}',
                      style: Fonts.display(size: 24, color: numberColor))
                  : Icon(Icons.lock_rounded, size: 22, color: t.muted),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (current)
          _bounce(
            on,
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 3),
                    Text('PLAY',
                        style: Fonts.ui(
                            size: 12,
                            color: Colors.white,
                            weight: FontWeight.w800,
                            letterSpacing: 0.5,
                            height: 1)),
                  ],
                ),
              ),
            ),
          )
        else if (def.unlocks != null && cleared)
          Text('new: ${def.unlocks}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fonts.ui(size: 10, color: t.muted, height: 1)),
      ],
    );
  }

  /// Slow breathe for the current node (handoff `glow`).
  Widget _pulse(bool on, Widget child) => on
      ? child
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1,
              end: 1.06,
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut)
      : child;

  /// Up-and-down hop for the PLAY pill (handoff `lvlBounce`).
  Widget _bounce(bool on, Widget child) => on
      ? child
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
              begin: 0,
              end: -8,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut)
      : child;
}

/// A campaign level on the branching engine: its fixed (tier, seed) board.
/// "Play again" retries the same level; the win records stars, which unlocks
/// the next node on the roadmap.
void _openBranchingLevel(BuildContext context, GameController g, LevelDef def) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TreeGamePage(
        tier: def.tier.name,
        puzzle: buildPuzzle(def.tier.name, def.seed),
        onWin: (m, p) {
          g.recordCampaignWin(def.no, m, p);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}
