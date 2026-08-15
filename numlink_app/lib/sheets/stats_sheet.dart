import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../models/achievement.dart';
import '../models/game_stats.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/streak_flame.dart';
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

    return BottomSheetShell(
      title: 'Statistics',
      onClose: g.close,
      children: [
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
          final isCurrent = g.solved && k == g.currentBucket;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(k == 'par' ? 'PAR' : k,
                      style: Fonts.mono(
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
                          color: isCurrent ? t.success : t.muted,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('$count',
                              style: Fonts.mono(
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
        _SectionLabel('BY MODE'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatCell(
                value: '${s.counters['practice'] ?? 0}', label: 'PRACTICE'),
            _StatCell(value: '${s.counters['zen'] ?? 0}', label: 'ZEN'),
            _StatCell(
                value: '${s.archiveSolved.length}', label: 'ARCHIVE'),
            _StatCell(
                value: '${s.counters['timedBestStage'] ?? 0}',
                label: 'TIMED BEST'),
          ],
        ),
        const SizedBox(height: 22),
        _SectionLabel('BADGES'),
        const SizedBox(height: 12),
        ...kAchievements.map((a) => _BadgeRow(
              achievement: a,
              unlocked: s.unlocked.contains(a.id),
            )),
        const SizedBox(height: 14),
        PrimaryButton(
          label: g.copied ? 'Copied to clipboard' : 'Share result',
          onTap: () {
            Clipboard.setData(ClipboardData(text: g.shareText()));
            g.markCopied();
          },
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

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final c = unlocked ? t.text : t.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked ? tint(t.success, 0.14) : t.surface,
              border: Border.all(
                  color: unlocked ? t.success : t.border, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(unlocked ? '★' : '☆',
                style: Fonts.mono(
                    size: 15,
                    color: unlocked ? t.success : t.muted,
                    weight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.name,
                    style: Fonts.ui(
                        size: 14, color: c, weight: FontWeight.w700, height: 1.1)),
                const SizedBox(height: 2),
                Text(achievement.desc,
                    style: Fonts.ui(size: 12, color: t.muted, height: 1.2)),
              ],
            ),
          ),
        ],
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
                  style: Fonts.mono(size: 28, color: c, weight: FontWeight.w700)),
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
