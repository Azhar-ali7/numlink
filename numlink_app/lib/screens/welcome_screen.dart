import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'tree_game_page.dart';
import '../widgets/chunky_button.dart';
import '../widgets/streak_flame.dart';

/// Home hub — a vertically-banded learning-app landing cloned from the design
/// handoff (`design-handoff-current/NUMLINK.dc.html`):
///   1. Play — pink header (greeting + dark "today's chain" card) → white
///      "Learning progress" → orange orbit (Modes · Stats · Awards) →
///      teal XP-gauge band with the play control.
///   2. Progress (streak / puzzle / XP / Levels)
///   3. Modes (Practice / Zen / Timed / Archive)
///
/// Tabs live in an [IndexedStack] so every page stays in the tree (flow-test
/// `find`s across tabs still resolve, no lazy-build surprise); a bottom nav
/// switches between them.

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);

    // Every tab is a full-bleed vertical scroll so its colour bands reach the
    // screen edges; each page manages its own inner padding.
    return ColoredBox(
      color: t.bg,
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                SingleChildScrollView(
                  child: _PlayTab(
                    g: g,
                    onModes: () => setState(() => _tab = 2),
                  ),
                ),
                SingleChildScrollView(child: _ProgressPage(g: g)),
                SingleChildScrollView(child: _ModesPage(g: g)),
              ],
            ),
          ),
          _NavBar(active: _tab, onTap: (i) => setState(() => _tab = i)),
        ],
      ),
    );
  }
}

/// Bottom nav: Play · Stats · Modes. Active item is a filled teal pill. Kept as
/// the app's navigation spine (the banded hero is the Play tab's content).
class _NavBar extends StatelessWidget {
  const _NavBar({required this.active, required this.onTap});
  final int active;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.play_arrow_rounded, 'Play'),
    (Icons.insights_rounded, 'Stats'),
    (Icons.grid_view_rounded, 'Modes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: _Card(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  selected: i == active,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final color = selected ? Colors.white : t.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? t.success : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: Fonts.ui(
                size: 11,
                color: color,
                weight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 1 · Play — the banded learning-app hero ─────────────────────────────

class _PlayTab extends StatelessWidget {
  const _PlayTab({required this.g, required this.onModes});
  final GameController g;

  /// Switches the hub to the Modes tab (the orbit/gauge "modes" controls).
  final VoidCallback onModes;

  @override
  Widget build(BuildContext context) {
    final reduce = reducedMotion(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PinkHeaderBand(
          g: g,
        ).animateIf(!reduce, (w) => w.fadeIn(duration: 280.ms)),
        // pink → white wavy seam.
        const _WaveDivider(
          top: NumTokens.accent,
          bottom: Colors.white,
          startY: 52,
          c1: Offset(0.273, 4),
          c2: Offset(0.727, 8),
          endY: 44,
        ),
        _WhiteProgressBand(g: g),
        _OrangeOrbitBand(g: g, onModes: onModes),
        // orange → teal wavy seam.
        _WaveDivider(
          top: NumTheme.of(context).progress,
          bottom: NumTheme.of(context).success,
          startY: 26,
          c1: const Offset(0.341, 6),
          c2: const Offset(0.682, 116),
          endY: 70,
        ),
        _TealGaugeBand(g: g, onModes: onModes),
      ],
    );
  }
}

/// Band 1 — pink header: greeting + bell + avatar, then the dark navy "Today's
/// number chain" card carrying the primary "Play today's puzzle" CTA.
class _PinkHeaderBand extends StatelessWidget {
  const _PinkHeaderBand({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, topInset + 18, 22, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF08BA6), NumTokens.accent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, Player 👋',
                      style: Fonts.display(
                        size: 26,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      g.dailyPuzzle.dateLabel,
                      style: Fonts.ui(
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.82),
                        weight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              // Bell — opens stats (recent activity), with a star notification dot.
              _CircleIcon(
                size: 40,
                bg: Colors.white.withValues(alpha: 0.2),
                icon: Icons.notifications_none_rounded,
                iconColor: Colors.white,
                iconSize: 20,
                label: 'Activity',
                onTap: () => g.open(SheetOverlay.stats),
                badge: true,
              ),
              const SizedBox(width: 10),
              // Avatar — opens settings.
              Semantics(
                button: true,
                label: 'Profile & settings',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => g.open(SheetOverlay.settings),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [NumTokens.heroTwo, NumTokens.hero],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'P',
                      style: Fonts.display(
                        size: 18,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TodaysChainCard(g: g),
        ],
      ),
    );
  }
}

/// The daily CTA now opens today's board on the branching engine.
void _openDailyBranching(BuildContext context) {
  final g = context.read<GameController>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TreeGamePage(
        tier: 'medium',
        puzzle: dailyBranchingPuzzle(),
        onWin: (m, p) {
          g.recordDailyWin(m, p);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}

/// Practice/Zen now run on the branching engine too: a chosen-tier board with
/// New-board + difficulty controls. [mode] decides how the win is recorded.
void _openBranchingMode(BuildContext context, GameMode mode, String tier) {
  final g = context.read<GameController>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TreeGamePage(
        tier: tier,
        onWin: (m, p) {
          g.recordBranchingWin(mode, m, p);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}

/// Timed on the branching engine: a stopwatch race up the escalating ladder.
void _openBranchingTimed(BuildContext context) {
  final g = context.read<GameController>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimedTreePage(
        onStageSolved: (stage, runDone) {
          g.recordTimedStage(stage, runDone: runDone);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}

/// The dark navy card inside the pink band: puzzle number, title, and the
/// primary "Play today's puzzle" CTA (the flow test taps this → startDaily).
class _TodaysChainCard extends StatelessWidget {
  const _TodaysChainCard({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: NumTokens.nav,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DAILY PUZZLE · #${g.dailyPuzzle.no}',
                style: Fonts.ui(
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                  weight: FontWeight.w800,
                  letterSpacing: 1.4,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Today's number chain",
                style: Fonts.display(
                  size: 22,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Primary CTA — carries the literal "Play today's puzzle".
                  // Flexible + ellipsis so a tight width shrinks the pill
                  // instead of overflowing (the Text.data still matches the
                  // flow test's find.text).
                  Flexible(
                    child: Semantics(
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openDailyBranching(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: NumTokens.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  "Play today's puzzle",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Fonts.ui(
                                    size: 14,
                                    color: Colors.white,
                                    weight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => g.open(SheetOverlay.how),
                    child: Text(
                      'How to play',
                      style: Fonts.ui(
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                        weight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Corner how-to glyph.
          Positioned(
            top: 0,
            right: 0,
            child: _CircleIcon(
              size: 34,
              radius: 12,
              bg: Colors.transparent,
              border: Colors.white.withValues(alpha: 0.22),
              icon: Icons.north_east_rounded,
              iconColor: Colors.white.withValues(alpha: 0.8),
              iconSize: 15,
              label: 'How to play',
              onTap: () => g.open(SheetOverlay.how),
            ),
          ),
        ],
      ),
    );
  }
}

/// Band 2 — white "Learning progress": level kicker, heading, and two inline
/// stats (current streak / solved) split by a hairline divider.
class _WhiteProgressBand extends StatelessWidget {
  const _WhiteProgressBand({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      width: double.infinity,
      color: t.elevated,
      // Extra bottom room: the orange band's orbit circles overlap up onto it.
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level ${g.stats.playerLevel}',
            style: Fonts.ui(
              size: 12,
              color: t.muted,
              weight: FontWeight.w800,
              letterSpacing: 1,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Learning progress',
            style: Fonts.display(size: 30, color: t.text, height: 1.05),
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _InlineStat(
                    icon: Icons.local_fire_department_rounded,
                    tint: NumTokens.accent,
                    label: 'Current streak',
                    value:
                        '${g.stats.streak} '
                        '${g.stats.streak == 1 ? 'day' : 'days'}',
                  ),
                ),
                Container(width: 2, color: t.border),
                const SizedBox(width: 16),
                Expanded(
                  child: _InlineStat(
                    icon: Icons.check_rounded,
                    tint: t.success,
                    label: 'Solved',
                    value: '#${g.stats.totalSolves}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded-square icon chip + a small label over a bold value.
class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Fonts.ui(
                  size: 11,
                  color: t.muted,
                  weight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Fonts.display(size: 18, color: t.text, height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Band 3 — orange orbit: three circular controls straddling the white/orange
/// seam (Stats · Modes · Awards) over the caption.
class _OrangeOrbitBand extends StatelessWidget {
  const _OrangeOrbitBand({required this.g, required this.onModes});
  final GameController g;
  final VoidCallback onModes;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      width: double.infinity,
      color: t.progress,
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          // The row reserves 44px but the circles overflow up (Clip.none) so
          // they paint over the white band above — matching the -34px overlap.
          SizedBox(
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: -34,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _OrbitButton(
                        size: 58,
                        bg: NumTokens.hero,
                        ring: t.progress,
                        icon: Icons.emoji_events_rounded,
                        iconColor: Colors.white,
                        label: 'Stats',
                        onTap: () => g.open(SheetOverlay.stats),
                      ),
                      const SizedBox(width: 26),
                      _OrbitButton(
                        size: 78,
                        bg: NumTokens.nav,
                        ring: t.progress,
                        emoji: '🎮',
                        label: 'Game modes',
                        onTap: onModes,
                      ),
                      const SizedBox(width: 26),
                      _OrbitButton(
                        size: 58,
                        bg: Colors.white,
                        ring: t.progress,
                        icon: Icons.star_rounded,
                        iconColor: NumTokens.star,
                        label: 'Awards',
                        onTap: () => g.open(SheetOverlay.roadmap),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Modes · Stats · Awards',
            style: Fonts.ui(
              size: 12,
              color: const Color(0xFF5A4406),
              weight: FontWeight.w800,
              letterSpacing: 0.4,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A ringed circular orbit button (icon or emoji), drop-shadowed.
class _OrbitButton extends StatelessWidget {
  const _OrbitButton({
    required this.size,
    required this.bg,
    required this.ring,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.emoji,
  });

  final double size;
  final Color bg;
  final Color ring;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: ring, width: size >= 78 ? 5 : 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 30))
              : Icon(icon, size: size >= 78 ? 30 : 24, color: iconColor),
        ),
      ),
    );
  }
}

/// Band 4 — teal XP gauge: a semicircle level gauge over the play controls
/// (settings · play · modes). The play control also starts the daily.
class _TealGaugeBand extends StatelessWidget {
  const _TealGaugeBand({required this.g, required this.onModes});
  final GameController g;
  final VoidCallback onModes;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      color: t.success,
      padding: EdgeInsets.fromLTRB(26, 16, 26, 24 + bottomInset),
      child: Column(
        children: [
          _XpGauge(
            progress: g.stats.levelProgress.clamp(0.0, 1.0),
            level: g.stats.playerLevel,
            into: g.stats.xpIntoLevel,
            span: g.stats.xpLevelSpan,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleIcon(
                size: 52,
                bg: Colors.white.withValues(alpha: 0.18),
                icon: Icons.settings_rounded,
                iconColor: Colors.white,
                iconSize: 21,
                label: 'Settings',
                onTap: () => g.open(SheetOverlay.settings),
              ),
              const SizedBox(width: 26),
              // Big white play — also starts the daily (icon-only; the labelled
              // CTA lives in the navy card above for the flow test).
              Semantics(
                button: true,
                label: "Play today's puzzle",
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openDailyBranching(context),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x3D000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 34,
                      color: t.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 26),
              _CircleIcon(
                size: 52,
                bg: Colors.white.withValues(alpha: 0.18),
                icon: Icons.format_list_bulleted_rounded,
                iconColor: Colors.white,
                iconSize: 21,
                label: 'Modes',
                onTap: onModes,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The semicircle XP gauge: a full track arc + a foreground progress arc, with
/// the level and XP readout stacked at the base. A small white scrubber marker
/// sweeps back and forth along the arc (media-player feel); under reduced
/// motion it sits still at the current XP point.
class _XpGauge extends StatefulWidget {
  const _XpGauge({
    required this.progress,
    required this.level,
    required this.into,
    required this.span,
  });

  final double progress;
  final int level;
  final int into;
  final int span;

  @override
  State<_XpGauge> createState() => _XpGaugeState();
}

class _XpGaugeState extends State<_XpGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reducedMotion(context);
    // Start/stop the loop to match the motion preference (which can change).
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }

    return SizedBox(
      width: 220,
      height: 122,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                painter: _GaugePainter(
                  progress: widget.progress,
                  // Ease the linear controller into a soft sweep; hold at the
                  // XP point when motion is reduced.
                  scrub: reduce
                      ? widget.progress
                      : Curves.easeInOut.transform(_c.value),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Lv ${widget.level}',
                  style: Fonts.display(
                    size: 32,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.into} / ${widget.span} XP',
                  style: Fonts.ui(
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.82),
                    weight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress, required this.scrub});
  final double progress;

  /// 0..1 position of the sweeping marker along the arc (π → 2π).
  final double scrub;

  @override
  void paint(Canvas canvas, Size size) {
    // A 184-wide arc of radius 92 centred near the base, sweeping the top
    // semicircle (π → 2π). Mirrors the handoff's `A 92 92 … 18,110→202,110`.
    const r = 92.0;
    final center = Offset(size.width / 2, 110);
    final rect = Rect.fromCircle(center: center, radius: r);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawArc(rect, math.pi, math.pi, false, track);

    if (progress > 0) {
      final fg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..color = Colors.white;
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * progress.clamp(0.0, 1.0),
        false,
        fg,
      );
    }

    // Scrubber marker: a white knob with a teal core, riding on the arc.
    final angle = math.pi + math.pi * scrub.clamp(0.0, 1.0);
    final knob = center + Offset(math.cos(angle), math.sin(angle)) * r;
    canvas.drawCircle(
      knob,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      knob,
      4.5,
      Paint()
        ..color = const Color(0xFF2F9184)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.scrub != scrub;
}

/// A wavy colour seam between two bands: [top] fills above the cubic curve,
/// [bottom] below — the Flutter equivalent of the handoff's overlapping SVG
/// wave. Control-point Y's are in the handoff's 0–88 space; X's are fractions
/// of the width.
class _WaveDivider extends StatelessWidget {
  const _WaveDivider({
    required this.top,
    required this.bottom,
    required this.startY,
    required this.c1,
    required this.c2,
    required this.endY,
  });

  final Color top;
  final Color bottom;
  final double startY;
  final Offset c1; // (xFraction, y in 0–88)
  final Offset c2;
  final double endY;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: CustomPaint(
        painter: _WavePainter(top, bottom, startY, c1, c2, endY),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.top, this.bottom, this.startY, this.c1, this.c2, this.endY);
  final Color top;
  final Color bottom;
  final double startY;
  final Offset c1;
  final Offset c2;
  final double endY;

  static const _srcH = 88.0;

  @override
  void paint(Canvas canvas, Size size) {
    final sy = size.height / _srcH;
    canvas.drawRect(Offset.zero & size, Paint()..color = top);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, startY * sy)
      ..cubicTo(
        c1.dx * size.width,
        c1.dy * sy,
        c2.dx * size.width,
        c2.dy * sy,
        size.width,
        endY * sy,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = bottom);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.top != top || old.bottom != bottom;
}

/// A circular (or rounded-square) icon button used across the bands, with an
/// optional small notification badge dot.
class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.size,
    required this.bg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.iconSize = 20,
    this.radius,
    this.border,
    this.badge = false,
  });

  final double size;
  final Color bg;
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;
  final VoidCallback onTap;

  /// When set, renders a rounded square of this corner radius instead of a circle.
  final double? radius;
  final Color? border;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
    if (badge) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NumTokens.star,
                border: Border.all(color: NumTokens.accent, width: 2),
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: button,
      ),
    );
  }
}

/// Full-bleed gradient header used to open the Stats and Modes tabs, echoing the
/// Play tab's pink header so every tab reads as the same banded learning-app.
class _BandHeader extends StatelessWidget {
  const _BandHeader({
    required this.colorTop,
    required this.colorBottom,
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final Color colorTop;
  final Color colorBottom;
  final String kicker;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [colorTop, colorBottom],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker,
                  style: Fonts.ui(
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    weight: FontWeight.w800,
                    letterSpacing: 1.6,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: Fonts.display(
                    size: 30,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Fonts.ui(
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ── Page 2 · Progress ──────────────────────────────────────────────────────

class _ProgressPage extends StatelessWidget {
  const _ProgressPage({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BandHeader(
          colorTop: const Color(0xFF3CA79A),
          colorBottom: t.success,
          kicker: 'LEVEL ${g.stats.playerLevel}',
          title: 'Your progress',
          subtitle:
              '${g.stats.streak}-day streak · ${g.stats.xpIntoLevel}/${g.stats.xpLevelSpan} XP',
          icon: Icons.insights_rounded,
        ),
        _WaveDivider(
          top: t.success,
          bottom: t.bg,
          startY: 40,
          c1: const Offset(0.3, 6),
          c2: const Offset(0.7, 88),
          endY: 40,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: '${g.stats.streak}',
                      label: 'DAY STREAK',
                      valueColor: NumTokens.accentOrange,
                      flame: true,
                      freezes: g.stats.freezes,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: '#${g.dailyPuzzle.no}',
                      label: g.dailyPuzzle.dateLabel,
                      valueColor: NumTokens.accentBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Card(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: _XpBar(
                  level: g.stats.playerLevel,
                  progress: g.stats.levelProgress,
                  into: g.stats.xpIntoLevel,
                  span: g.stats.xpLevelSpan,
                ),
              ),
              const SizedBox(height: 14),
              _LevelsEntry(
                cleared: g.stats.campaignCleared,
                total: g.campaignCount,
                stars: g.stats.campaignStars,
                onTap: () => g.open(SheetOverlay.roadmap),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Page 3 · Modes ─────────────────────────────────────────────────────────

class _ModesPage extends StatelessWidget {
  const _ModesPage({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BandHeader(
          colorTop: NumTokens.heroTwo,
          colorBottom: NumTokens.hero,
          kicker: 'MORE WAYS TO PLAY',
          title: 'Game modes',
          subtitle: 'Practice, unwind, or race the clock',
          icon: Icons.grid_view_rounded,
        ),
        _WaveDivider(
          top: NumTokens.hero,
          bottom: t.bg,
          startY: 40,
          c1: const Offset(0.3, 88),
          c2: const Offset(0.7, 6),
          endY: 40,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  _ModeTile(
                    tag: 'PRACTICE',
                    blurb: 'Unlimited puzzles at your pace',
                    icon: Icons.all_inclusive_rounded,
                    color: NumTokens.accentBlue,
                    onTap: () => _showDifficultySheet(context,
                        (d) => _openBranchingMode(context, GameMode.practice, d.name)),
                  ),
                  _ModeTile(
                    tag: 'ZEN',
                    blurb: 'No clock, no par, no streak',
                    icon: Icons.spa_rounded,
                    color: NumTokens.accentPurple,
                    onTap: () => _showDifficultySheet(context,
                        (d) => _openBranchingMode(context, GameMode.zen, d.name)),
                  ),
                  _ModeTile(
                    tag: 'TIMED',
                    blurb: 'Climb the escalating ladder',
                    icon: Icons.bolt_rounded,
                    color: NumTokens.accentOrange,
                    onTap: () => _openBranchingTimed(context),
                  ),
                  _ModeTile(
                    tag: 'ARCHIVE',
                    blurb: 'Replay past daily puzzles',
                    icon: Icons.calendar_month_rounded,
                    color: NumTokens.accentPink,
                    onTap: () => g.open(SheetOverlay.archive),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => g.open(SheetOverlay.how),
                  child: Text(
                    'How to play',
                    style: Fonts.ui(
                      size: 14,
                      color: t.muted,
                      weight: FontWeight.w700,
                      height: 1,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared bright primitives ─────────────────────────────────────────────────

/// Applies [build] (a flutter_animate chain) only when [enabled].
extension _MaybeAnimate on Widget {
  Widget animateIf(bool enabled, Animate Function(Animate) build) =>
      enabled ? build(animate()) : this;
}

/// A solid bright card: token fill, hairline border, soft drop shadow. Tuned for
/// the light Duo-playful theme; reads fine on the secondary dark theme too.
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color,
    this.border,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Color? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.elevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? t.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tint(t.text, 0.06),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      panel = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: panel,
      );
    }
    return panel;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
    this.flame = false,
    this.freezes = 0,
  });

  final String value;
  final String label;
  final Color valueColor;
  final bool flame;

  /// Streak-freezes banked; shown as a small ❄ N badge when > 0.
  final int freezes;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final streak = int.tryParse(value) ?? 0;
    return _Card(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                value,
                style: Fonts.mono(
                  size: 26,
                  color: valueColor,
                  weight: FontWeight.w700,
                ),
              ),
              if (flame && streak > 0) ...[
                const SizedBox(width: 5),
                StreakFlame(streak: streak, color: valueColor, size: 20),
              ],
              if (freezes > 0) ...[
                const Spacer(),
                Icon(Icons.ac_unit, size: 14, color: NumTokens.accentBlue),
                const SizedBox(width: 2),
                Text(
                  '$freezes',
                  style: Fonts.mono(
                    size: 13,
                    color: NumTokens.accentBlue,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Fonts.ui(
              size: 10,
              color: t.muted,
              weight: FontWeight.w700,
              letterSpacing: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A home-grid tile for a secondary mode: a colored icon chip, tag, and blurb on
/// a soft pastel card tinted with the mode's accent color.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.tag,
    required this.blurb,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tag;
  final String blurb;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return _Card(
      radius: 18,
      onTap: onTap,
      color: tint(color, 0.12),
      border: tint(color, 0.35),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tag,
                style: Fonts.ui(
                  size: 14,
                  color: t.text,
                  weight: FontWeight.w700,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                blurb,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Fonts.ui(size: 11, color: t.muted, height: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Player-level XP bar: level number, a progress fill toward the next level,
/// and the raw XP-into/span readout.
class _XpBar extends StatelessWidget {
  const _XpBar({
    required this.level,
    required this.progress,
    required this.into,
    required this.span,
  });

  final int level;
  final double progress;
  final int into;
  final int span;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LEVEL $level',
              style: Fonts.ui(
                size: 11,
                color: t.text,
                weight: FontWeight.w700,
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
            Text(
              '$into / $span XP',
              style: Fonts.mono(size: 11, color: t.muted, height: 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: tint(t.text, 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(t.progress),
          ),
        ),
      ],
    );
  }
}

/// Full-width campaign entry into the curated roadmap.
class _LevelsEntry extends StatelessWidget {
  const _LevelsEntry({
    required this.cleared,
    required this.total,
    required this.stars,
    required this.onTap,
  });

  final int cleared;
  final int total;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return _Card(
      radius: 18,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.map_rounded, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVELS',
                  style: Fonts.ui(
                    size: 16,
                    color: t.text,
                    weight: FontWeight.w700,
                    letterSpacing: 1.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Climb the curated roadmap · $cleared/$total cleared',
                  style: Fonts.ui(size: 12, color: t.muted, height: 1.2),
                ),
              ],
            ),
          ),
          Icon(Icons.star_rounded, size: 20, color: t.progress),
          const SizedBox(width: 4),
          Text(
            '$stars',
            style: Fonts.mono(size: 18, color: t.text, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Quick difficulty chooser for Practice/Zen.
void _showDifficultySheet(
  BuildContext context,
  void Function(Difficulty) onStart,
) {
  final t = NumTheme.of(context);
  var selected = Difficulty.medium;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) => Container(
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: t.border, width: 1.4)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(sheetCtx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose difficulty',
              style: Fonts.display(size: 24, color: t.text),
            ),
            const SizedBox(height: 16),
            _DifficultyPicker(
              selected: selected,
              onSelect: (d) => setSheet(() => selected = d),
            ),
            const SizedBox(height: 18),
            ChunkyButton(
              color: t.success,
              radius: 16,
              padding: const EdgeInsets.symmetric(vertical: 16),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                onStart(selected);
              },
              child: Text(
                'Start ${selected.label}',
                style: Fonts.ui(
                  size: 16,
                  color: Colors.white,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Three-way difficulty segmented control.
class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected, required this.onSelect});

  final Difficulty selected;
  final ValueChanged<Difficulty> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tint(t.text, 0.04),
        border: Border.all(color: t.border, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final d in Difficulty.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: d == selected ? tint(t.success, 0.16) : null,
                    border: d == Difficulty.hard
                        ? null
                        : Border(
                            right: BorderSide(color: t.border, width: 1.2),
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    d.label,
                    style: Fonts.ui(
                      size: 13,
                      color: d == selected ? t.success : t.muted,
                      weight: FontWeight.w700,
                      letterSpacing: 0.3,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
