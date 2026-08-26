import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../models/achievement.dart';
import '../models/game_stats.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/streak_flame.dart';
import '../widgets/ui.dart';
import 'bottom_sheet_shell.dart';

class StatsSheet extends StatelessWidget {
  const StatsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final s = g.stats;

    final maxCount = [
      1,
      ...GameStats.bucketKeys.map((k) => s.dist[k] ?? 0),
    ].reduce((a, b) => a > b ? a : b);
    final on = !reducedMotion(context);

    return BottomSheetShell(
      title: 'Statistics',
      onClose: g.close,
      children: [
        entrance(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatCell(value: '${s.played}', label: 'PLAYED'),
              _StatCell(value: '${s.winRate}', label: 'WIN %'),
              _StatCell(
                  value: '${s.streak}',
                  label: 'STREAK',
                  color: t.success,
                  flame: true),
              _StatCell(value: '${s.maxStreak}', label: 'BEST'),
            ],
          ),
          on: on,
          index: 0,
        ),
        const SizedBox(height: 16),
        entrance(_FreezeCard(freezes: s.freezes), on: on, index: 1),
        const SizedBox(height: 12),
        entrance(
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                    label: 'HANDICAP', value: s.handicap.toStringAsFixed(1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBox(
                    label: 'COURSE RECORD', value: s.courseRecord),
              ),
            ],
          ),
          on: on,
          index: 2,
        ),
        const SizedBox(height: 22),
        Text('MOVES vs PAR',
            style: Fonts.ui(
                size: 11,
                color: t.muted,
                weight: FontWeight.w700,
                letterSpacing: 1.5,
                height: 1)),
        const SizedBox(height: 12),
        ...GameStats.bucketKeys.map((k) {
          final count = s.dist[k] ?? 0;
          final pct = (100 * count / maxCount).round();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(k == 'par' ? 'PAR' : k,
                      style: Fonts.numeric(
                          size: 13, color: t.text, weight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (pct / 100).clamp(0.0, 1.0),
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 26),
                          color: t.muted,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('$count',
                              style: Fonts.numeric(
                                  size: 12,
                                  color: Colors.white,
                                  weight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 22),
        _SectionLabel('ACHIEVEMENTS'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in kAchievements)
              _BadgeChip(
                achievement: a,
                unlocked: s.unlocked.contains(a.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Text(text,
        style: Fonts.ui(
            size: 11,
            color: t.muted,
            weight: FontWeight.w700,
            letterSpacing: 1.5,
            height: 1));
  }
}

/// The banked streak-freeze card: a shield tile + count + one-line copy.
class _FreezeCard extends StatelessWidget {
  const _FreezeCard({required this.freezes});
  final int freezes;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border, width: 2),
        boxShadow: t.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint(t.accent, 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text('🛡', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$freezes',
                        style: Fonts.numeric(
                            size: 20, color: t.text, weight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text('STREAK FREEZE${freezes == 1 ? '' : 'S'}',
                        style: Fonts.ui(
                            size: 12,
                            color: t.text,
                            weight: FontWeight.w800,
                            letterSpacing: 0.5,
                            height: 1)),
                  ],
                ),
                const SizedBox(height: 3),
                Text('Banked saves for a missed day.',
                    style: Fonts.ui(size: 12, color: t.muted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled metric box (HANDICAP / COURSE RECORD).
class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border, width: 2),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Fonts.numeric(
                  size: 22, color: t.text, weight: FontWeight.w700)),
          const SizedBox(height: 3),
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

/// One achievement pill: name only, dimmed when locked.
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Opacity(
      opacity: unlocked ? 1 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: unlocked ? tint(t.success, 0.12) : t.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: unlocked ? t.success : t.border, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(unlocked ? '★' : '☆',
                style: Fonts.numeric(
                    size: 13,
                    color: unlocked ? t.success : t.muted,
                    weight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text(achievement.name,
                style: Fonts.ui(
                    size: 12.5,
                    color: unlocked ? t.text : t.muted,
                    weight: FontWeight.w700,
                    height: 1)),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.color,
    this.flame = false,
  });

  final String value;
  final String label;
  final Color? color;
  final bool flame;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final c = color ?? t.text;
    final streak = int.tryParse(value) ?? 0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(value,
                  style: Fonts.numeric(size: 28, color: c, weight: FontWeight.w700)),
              if (flame && streak > 0) ...[
                const SizedBox(width: 4),
                StreakFlame(streak: streak, color: c, size: 18),
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
