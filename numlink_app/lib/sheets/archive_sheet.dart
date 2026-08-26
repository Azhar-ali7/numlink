import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../screens/tree_game_page.dart';
import '../screens/welcome_screen.dart' show openDailyBranching;
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'bottom_sheet_shell.dart';

/// The daily archive as a month calendar (design handoff): a "MONTH YEAR" header
/// with prev/next nav, Mo–Su weekday labels, and a day grid where each cell cues
/// its state — solved / today / missed / upcoming — and tapping a playable past
/// daily (or today) loads that board. Replaying never touches the streak.
class ArchiveSheet extends StatefulWidget {
  const ArchiveSheet({super.key, this.asRoute = false});

  /// When true this sheet is a pushed route (opened from the pushed Game-modes
  /// screen, where the app-shell overlay layer sits *behind* the route) and
  /// dismisses by popping; when false it's the app-shell overlay (from Home)
  /// and dismisses via [GameController.close].
  final bool asRoute;

  @override
  State<ArchiveSheet> createState() => _ArchiveSheetState();
}

class _ArchiveSheetState extends State<ArchiveSheet> {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _wd = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  // The month being viewed (first-of-month), defaults to the current month.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayNo = g.dailyPuzzle.no;
    // Puzzle number for a calendar date, relative to today's known number.
    int noFor(DateTime d) => todayNo + d.difference(today).inDays;

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Leading blanks so day 1 sits under its weekday (Mon = 0).
    final lead = (DateTime(_month.year, _month.month, 1).weekday - 1) % 7;

    void dismiss() =>
        widget.asRoute ? Navigator.of(context).pop() : g.close();

    return BottomSheetShell(
      title: 'Archive',
      onClose: dismiss,
      children: [
        Text('Replay any past daily — just for fun, no streak.',
            style: Fonts.ui(size: 13, color: t.muted, height: 1.3)),
        const SizedBox(height: 16),
        // Month header + prev/next.
        Row(
          children: [
            Text('DAILY ARCHIVE',
                style: Fonts.ui(
                    size: 10,
                    color: t.muted,
                    weight: FontWeight.w800,
                    letterSpacing: 1.4,
                    height: 1)),
            const Spacer(),
            _NavArrow(icon: Icons.chevron_left_rounded, onTap: () => _shift(-1)),
            const SizedBox(width: 6),
            _NavArrow(icon: Icons.chevron_right_rounded, onTap: () => _shift(1)),
          ],
        ),
        const SizedBox(height: 4),
        Text('${_months[_month.month - 1]} ${_month.year}',
            style: Fonts.display(size: 22, color: t.text, height: 1.1)),
        const SizedBox(height: 14),
        // Weekday labels.
        Row(
          children: [
            for (final d in _wd)
              Expanded(
                child: Center(
                  child: Text(d,
                      style: Fonts.ui(
                          size: 10,
                          color: t.muted,
                          weight: FontWeight.w800,
                          height: 1)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // Day grid (7 columns).
        GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _dayCell(context, g, t, DateTime(_month.year, _month.month, day),
                  today, noFor),
          ],
        ),
        const SizedBox(height: 16),
        // Legend.
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _Legend(color: t.success, label: 'Solved'),
            _Legend(color: t.hero, label: 'Under par'),
            _Legend(color: t.progress, label: 'Over par'),
            _Legend(color: t.accent, label: 'Today'),
            _Legend(color: t.border, label: 'Missed / upcoming'),
          ],
        ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, GameController g, NumTokens t,
      DateTime date, DateTime today, int Function(DateTime) noFor) {
    final no = noFor(date);
    final isToday = date == today;
    final playablePast = g.archiveNumbers.contains(no);
    final solved = g.stats.archiveSolved.contains(no);

    Color border, dayColor, bg, markColor;
    final String mark;
    if (isToday) {
      border = markColor = dayColor = t.accent;
      bg = tint(t.accent, 0.14);
      mark = '▸';
    } else if (solved) {
      border = markColor = dayColor = t.success;
      bg = tint(t.success, 0.12);
      mark = '✓';
    } else if (playablePast) {
      border = t.border;
      bg = Colors.transparent;
      dayColor = t.text;
      markColor = t.muted;
      mark = '·';
    } else {
      // Pre-launch or upcoming — no board to play.
      border = Colors.transparent;
      bg = Colors.transparent;
      dayColor = t.muted;
      markColor = Colors.transparent;
      mark = '';
    }

    final tappable = isToday || playablePast;
    return GestureDetector(
      onTap: tappable
          ? () {
              if (isToday) {
                if (widget.asRoute) Navigator.of(context).pop();
                openDailyBranching(context);
                return;
              }
              // Dismiss this sheet, then open the board on top.
              widget.asRoute ? Navigator.of(context).pop() : g.close();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TreeGamePage(
                    tier: 'medium',
                    puzzle: archiveBranchingPuzzle(no),
                    onWin: (m, p) {
                      g.recordBranchingWin(GameMode.archive, m, p,
                          archiveNo: no);
                      return WinRecord(
                          xpGained: g.lastXpGain,
                          level: g.playerLevel,
                          streak: g.stats.streak);
                    },
                  ),
                ),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}',
                style: Fonts.display(size: 14, color: dayColor, height: 1)),
            const SizedBox(height: 3),
            Text(mark,
                style: TextStyle(fontSize: 10, color: markColor, height: 1)),
          ],
        ),
      ),
    );
  }
}

/// A round-bordered nav arrow for the month header.
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border, width: 2),
        ),
        child: Icon(icon, size: 18, color: t.text),
      ),
    );
  }
}

/// One legend entry: a colored dot + label.
class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Fonts.ui(size: 11, color: t.muted, height: 1)),
      ],
    );
  }
}
