import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../screens/tree_game_page.dart';
import '../screens/welcome_screen.dart' show openDailyBranching;
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'bottom_sheet_shell.dart';

/// One leaderboard row: name, level, a per-tab score, and an avatar hue.
/// `score` is XP (week/all-time) or moves-vs-par (today's par).
typedef _Row = ({String name, int level, int? score, Color color});

/// The friends leaderboard (mock cohort per docs §11), rebuilt to the handoff:
/// an eyebrow + "Friends" heading, a This Week / Today's par / All-time tab
/// pill, top-3 podium cards, a plain list for the rest, and a "Play today's
/// puzzle" CTA. The "You" row uses the real player level/XP; everyone else is
/// fixed mock data.
class LeaderboardSheet extends StatefulWidget {
  const LeaderboardSheet({super.key});

  @override
  State<LeaderboardSheet> createState() => _LeaderboardSheetState();
}

class _LeaderboardSheetState extends State<LeaderboardSheet> {
  // 'week' | 'today' | 'all'
  String _tab = 'week';

  // Mock friend cohort (prototype rosters); avatar hues carried per row.
  static const _week = <_Row>[
    (name: 'Ivo', level: 8, score: 540, color: Color(0xFFEC6A8D)),
    (name: 'Mara', level: 9, score: 510, color: Color(0xFF2F9184)),
    (name: 'You', level: 7, score: 470, color: Color(0xFFEFA42F)),
    (name: 'Sol', level: 6, score: 430, color: Color(0xFFE07A4F)),
    (name: 'Priya', level: 6, score: 390, color: Color(0xFF7A6CD6)),
    (name: 'Dan', level: 5, score: 350, color: Color(0xFF4C9FD6)),
  ];
  static const _all = <_Row>[
    (name: 'Mara', level: 9, score: 2140, color: Color(0xFF2F9184)),
    (name: 'Ivo', level: 8, score: 1880, color: Color(0xFFEC6A8D)),
    (name: 'You', level: 7, score: 1520, color: Color(0xFFEFA42F)),
    (name: 'Priya', level: 6, score: 1180, color: Color(0xFF7A6CD6)),
    (name: 'Dan', level: 5, score: 920, color: Color(0xFF4C9FD6)),
    (name: 'Lena', level: 5, score: 860, color: Color(0xFFE07A4F)),
  ];

  /// Rows for the current tab. Week/all-time substitute the real player level/XP
  /// into the "You" row (rank kept fixed — the cohort is mock either way).
  /// Today's par ranks friends' daily scores against today's par, low = best.
  List<_Row> _roster(GameController g) {
    final me = (level: g.playerLevel, xp: g.stats.xp);
    if (_tab == 'today') {
      final par = dailyBranchingPuzzle().par;
      final rows = <_Row>[
        (name: 'Ivo', level: 8, score: par - 1, color: Color(0xFFEC6A8D)),
        (name: 'Mara', level: 9, score: par, color: const Color(0xFF2F9184)),
        (name: 'Sol', level: 6, score: par + 1, color: const Color(0xFFE07A4F)),
        (name: 'Priya', level: 6, score: par, color: const Color(0xFF7A6CD6)),
        (name: 'Dan', level: 5, score: par + 2, color: const Color(0xFF4C9FD6)),
        if (g.todaySolved)
          (name: 'You', level: me.level, score: par, color: Color(0xFFEFA42F)),
      ]..sort((a, b) => a.score!.compareTo(b.score!));
      return rows;
    }
    final base = _tab == 'all' ? _all : _week;
    return [
      for (final r in base)
        r.name == 'You'
            ? (name: 'You', level: me.level, score: me.xp, color: r.color)
            : r,
    ];
  }

  String _fmtScore(int v, {required int par}) {
    if (_tab == 'today') {
      final o = v - par;
      return o <= -2 ? 'Eagle' : (o == -1 ? 'Birdie' : (o == 0 ? 'Par' : '+$o'));
    }
    final n = v.toString();
    return _tab == 'week' ? '+$n XP' : '$n XP';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final roster = _roster(g);
    final par = _tab == 'today' ? dailyBranchingPuzzle().par : 0;
    final top = roster.take(3).toList();
    final rest = roster.skip(3).toList();

    return BottomSheetShell(
      title: 'Friends',
      onClose: g.close,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('YOUR CIRCLE · BY XP',
              style: Fonts.ui(
                  size: 12,
                  color: t.muted,
                  weight: FontWeight.w800,
                  letterSpacing: 1.5,
                  height: 1)),
          const SizedBox(height: 4),
          Text('Friends', style: Fonts.display(size: 34, color: t.text)),
        ],
      ),
      children: [
        // Tab pill.
        Container(
          decoration: BoxDecoration(
            color: tint(t.text, 0.05),
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.all(5),
          child: Row(children: [
            _Tab(label: 'This Week', on: _tab == 'week', onTap: () => setState(() => _tab = 'week')),
            _Tab(label: "Today's par", on: _tab == 'today', onTap: () => setState(() => _tab = 'today')),
            _Tab(label: 'All-time', on: _tab == 'all', onTap: () => setState(() => _tab = 'all')),
          ]),
        ),
        const SizedBox(height: 18),
        // Podium (top 3).
        for (int i = 0; i < top.length; i++) ...[
          entrance(
            _PodiumCard(row: top[i], rank: i + 1, score: _fmtScore(top[i].score!, par: par)),
            on: !reducedMotion(context),
            index: i,
          ),
          if (i < top.length - 1) const SizedBox(height: 12),
        ],
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < rest.length; i++)
                  _RestRow(row: rest[i], rank: i + 4, score: _fmtScore(rest[i].score!, par: par)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        // CTA: close the leaderboard and open today's daily.
        _PlayDailyCta(onTap: () {
          g.close();
          openDailyBranching(context);
        }),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: on ? t.elevated : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fonts.display(
                  size: 13,
                  weight: 700,
                  color: on ? t.success : t.muted)),
        ),
      ),
    );
  }
}

/// An avatar disc with the person's initial.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color, this.size = 44, this.ring = false});
  final String name;
  final Color color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: Colors.white.withValues(alpha: 0.65), width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(name[0],
          style: Fonts.display(size: size * 0.4, color: Colors.white, weight: 800)),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.row, required this.rank, required this.score});
  final _Row row;
  final int rank;
  final String score;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    // Per-rank card palette (gold accent / neutral / amber), matching the proto.
    final (Color card, Color text, Color sub, Color pillBg, Color pillText) = switch (rank) {
      1 => (t.accent, Colors.white, Colors.white.withValues(alpha: 0.82), Colors.white, t.accent),
      2 => (t.elevated, t.text, t.muted, t.bg, t.text),
      _ => (t.progress, const Color(0xFF3D2A08), const Color(0xB33D2A08), Colors.white, const Color(0xFF8A5A00)),
    };
    const medal = ['🥇', '🥈', '🥉'];
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(medal[rank - 1], style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Text('#$rank', style: Fonts.display(size: 24, color: text, weight: 800)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fonts.ui(size: 15, color: text, weight: FontWeight.w800)),
              Text(score, style: Fonts.ui(size: 12, color: sub, weight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text('Lv ${row.level}',
              style: Fonts.display(size: 14, color: pillText, weight: 800)),
        ),
        const SizedBox(width: 10),
        _Avatar(name: row.name, color: row.color, size: 48, ring: true),
      ]),
    );
  }
}

class _RestRow extends StatelessWidget {
  const _RestRow({required this.row, required this.rank, required this.score});
  final _Row row;
  final int rank;
  final String score;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: Text('#$rank', style: Fonts.display(size: 16, color: t.muted, weight: 800)),
        ),
        _Avatar(name: row.name, color: row.color, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(row.name, style: Fonts.ui(size: 14, color: t.text, weight: FontWeight.w800)),
              Text(score, style: Fonts.ui(size: 11, color: t.muted, weight: FontWeight.w700)),
            ],
          ),
        ),
        Text('Lv ${row.level}', style: Fonts.display(size: 15, color: t.text, weight: 800)),
      ]),
    );
  }
}

class _PlayDailyCta extends StatelessWidget {
  const _PlayDailyCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('READY?',
                    style: Fonts.ui(
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                        weight: FontWeight.w800,
                        letterSpacing: 1)),
                const SizedBox(height: 2),
                Text('Play today’s puzzle',
                    style: Fonts.display(size: 22, color: Colors.white, weight: 800, height: 1)),
              ],
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
          ),
        ]),
      ),
    );
  }
}
