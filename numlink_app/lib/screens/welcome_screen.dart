import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../sheets/bottom_sheet_shell.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/next_daily_countdown.dart';
import '../widgets/streak_flame.dart';

/// Branded landing shown before play: mini chain preview, wordmark, streak +
/// puzzle stat cards, and the launch buttons.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final reduce = reducedMotion(context);

    final Widget preview = _PopIn(
      enabled: !reduce,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PreviewNode(
              value: '${g.dailyPuzzle.start}', color: t.text, border: t.border),
          _Connector(color: t.border),
          _DashedQ(color: t.muted),
          _Connector(color: t.border),
          _PreviewNode(
            value: '${g.dailyPuzzle.target}',
            color: t.success,
            border: t.success,
            bg: tint(t.success, 0.12),
          ),
        ],
      ),
    );

    // One centered column (content + CTAs together). No Expanded / no
    // IntrinsicHeight, so it can never overflow: on tall screens the block
    // centers, on short screens the whole thing scrolls.
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(child: preview),
        const SizedBox(height: 26),
        Text('NUMLINK',
            style: Fonts.display(
                size: 64, color: t.text, letterSpacing: -1.5, height: 0.92)),
        const SizedBox(height: 12),
        SizedBox(
          width: 300,
          child: Text(
            'Chain the operations. Turn the start number into the target in '
            'as few moves as you can.',
            style: Fonts.ui(size: 16, color: t.muted, height: 1.4),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${g.stats.streak}',
                label: 'DAY STREAK',
                valueColor: t.success,
                flame: true,
                freezes: g.stats.freezes,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '#${g.dailyPuzzle.no}',
                label: g.dailyPuzzle.dateLabel,
                valueColor: t.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _XpBar(
          level: g.stats.playerLevel,
          progress: g.stats.levelProgress,
          into: g.stats.xpIntoLevel,
          span: g.stats.xpLevelSpan,
        ),
        const SizedBox(height: 36),
        _WelcomeButton(
          label: "Play today's puzzle",
          filled: true,
          onTap: g.startDaily,
        ),
        const SizedBox(height: 12),
        const Center(child: NextDailyCountdown(center: true)),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('MORE MODES',
              style: Fonts.ui(
                  size: 11,
                  color: t.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 1.5,
                  height: 1)),
        ),
        const SizedBox(height: 12),
        _LevelsEntry(
          cleared: g.stats.campaignCleared,
          total: g.campaignCount,
          stars: g.stats.campaignStars,
          onTap: () => g.open(SheetOverlay.roadmap),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _ModeTile(
              tag: 'PRACTICE',
              blurb: 'Unlimited puzzles at your pace',
              onTap: () => _showDifficultySheet(context, g.startPractice),
            ),
            _ModeTile(
              tag: 'ZEN',
              blurb: 'No clock, no par, no streak',
              onTap: () => _showDifficultySheet(context, g.startZen),
            ),
            _ModeTile(
              tag: 'TIMED',
              blurb: 'Climb the escalating ladder',
              onTap: g.startTimed,
            ),
            _ModeTile(
              tag: 'ARCHIVE',
              blurb: 'Replay past daily puzzles',
              onTap: () => g.open(SheetOverlay.archive),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: () => g.open(SheetOverlay.how),
            child: Text('How to play',
                style: Fonts.ui(
                        size: 14,
                        color: t.muted,
                        weight: FontWeight.w700,
                        height: 1)
                    .copyWith(decoration: TextDecoration.underline)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );

    // Rendered fully opaque (no entrance opacity that could leave the screen
    // blank); the preview pop above is the entrance flourish. Wrapped in
    // Positioned.fill by the app shell, so this must NOT return a Positioned.
    return ColoredBox(
      color: t.bg,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// One-shot overshoot scale-in using a layout-neutral [Transform] so it never
/// interferes with intrinsic-height measurement (unlike a wrapping animation
/// widget that doesn't forward intrinsics).
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Motion.overshoot,
      child: child,
      builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
    );
  }
}

class _PreviewNode extends StatelessWidget {
  const _PreviewNode({
    required this.value,
    required this.color,
    required this.border,
    this.bg,
  });

  final String value;
  final Color color;
  final Color border;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: bg ?? t.surface,
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(value,
          style: Fonts.mono(size: 34, color: color, weight: FontWeight.w700)),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 2, height: 14, color: color);
}

class _DashedQ extends StatelessWidget {
  const _DashedQ({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('?',
          style: Fonts.mono(size: 12, color: color, weight: FontWeight.w700)),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: t.border, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(value,
                  style: Fonts.mono(
                      size: 24, color: valueColor, weight: FontWeight.w700)),
              if (flame && streak > 0) ...[
                const SizedBox(width: 5),
                StreakFlame(streak: streak, color: valueColor, size: 18),
              ],
              if (freezes > 0) ...[
                const Spacer(),
                Icon(Icons.ac_unit, size: 14, color: t.progress),
                const SizedBox(width: 2),
                Text('$freezes',
                    style: Fonts.mono(
                        size: 13, color: t.progress, weight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Fonts.ui(
                  size: 10,
                  color: t.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 1,
                  height: 1)),
        ],
      ),
    );
  }
}

/// A compact home-grid tile for a secondary mode.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.tag,
    required this.blurb,
    required this.onTap,
  });

  final String tag;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: t.border, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tag,
                  style: Fonts.ui(
                      size: 13,
                      color: t.text,
                      weight: FontWeight.w700,
                      letterSpacing: 1,
                      height: 1)),
              Text(blurb,
                  style: Fonts.ui(size: 12, color: t.muted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Player-level XP bar: level number, a progress fill toward the next level,
/// and the raw XP-into/span readout (the Zeigarnik "almost there" nudge).
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
            Text('LEVEL $level',
                style: Fonts.ui(
                    size: 11,
                    color: t.text,
                    weight: FontWeight.w700,
                    letterSpacing: 1.5,
                    height: 1)),
            Text('$into / $span XP',
                style: Fonts.mono(size: 11, color: t.muted, height: 1)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: tint(t.border, 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(t.progress),
          ),
        ),
      ],
    );
  }
}

/// Full-width campaign entry: the headline "more modes" row, showing progress
/// through the curated roadmap. Taps open the roadmap sheet.
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: tint(t.success, 0.10),
            border: Border.all(color: t.success, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEVELS',
                        style: Fonts.ui(
                            size: 15,
                            color: t.success,
                            weight: FontWeight.w700,
                            letterSpacing: 1.5,
                            height: 1)),
                    const SizedBox(height: 5),
                    Text('Climb the curated roadmap · $cleared/$total cleared',
                        style: Fonts.ui(size: 12, color: t.muted, height: 1.2)),
                  ],
                ),
              ),
              Icon(Icons.star_rounded, size: 18, color: t.progress),
              const SizedBox(width: 4),
              Text('$stars',
                  style: Fonts.mono(
                      size: 18, color: t.text, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick difficulty chooser for Practice/Zen: pick a tier, then [onStart]
/// generates a puzzle in that mode. Self-contained modal — no controller state.
void _showDifficultySheet(
    BuildContext context, void Function(Difficulty) onStart) {
  final t = NumTheme.of(context);
  var selected = Difficulty.medium;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) => Container(
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: t.border, width: 2)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(sheetCtx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose difficulty',
                style: Fonts.display(size: 24, color: t.text)),
            const SizedBox(height: 16),
            _DifficultyPicker(
              selected: selected,
              onSelect: (d) => setSheet(() => selected = d),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Start ${selected.label}',
              center: true,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                onStart(selected);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Three-way difficulty segmented control (settings-sheet visual language).
class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected, required this.onSelect});

  final Difficulty selected;
  final ValueChanged<Difficulty> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.border, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final d in Difficulty.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: d == selected ? tint(t.success, 0.14) : null,
                    border: d == Difficulty.hard
                        ? null
                        : Border(right: BorderSide(color: t.border, width: 2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(d.label,
                      style: Fonts.ui(
                          size: 13,
                          color: d == selected ? t.success : t.muted,
                          weight: FontWeight.w700,
                          letterSpacing: 0.3,
                          height: 1)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeButton extends StatefulWidget {
  const _WelcomeButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: widget.filled ? 18 : 14),
          decoration: BoxDecoration(
            color: widget.filled
                ? t.success.withValues(alpha: _hover ? 0.9 : 1)
                : Colors.transparent,
            border: widget.filled
                ? null
                : Border.all(
                    color: _hover ? t.success : t.border, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: Fonts.ui(
              size: widget.filled ? 17 : 14,
              color: widget.filled ? Colors.white : t.text,
              weight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
