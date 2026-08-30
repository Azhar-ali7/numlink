import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../flags.dart';
import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../screens/welcome_screen.dart' show openDailyBranching;
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'bottom_sheet_shell.dart';

/// Notifications (handoff Screen 8): exactly one live, unread daily-ready push,
/// a real streak-summary entry (only when the player actually has a streak),
/// and read-only log entries derived from real stats. The competitive
/// "friend passed you" nudge appears only when Settings → Social nudges is on.
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  /// Snapshotted on open, then marked read a frame later. Marking on close
  /// instead would miss the system back button and the scrim's own paths;
  /// marking without the snapshot would clear the highlight from under the
  /// player while they are still looking at the entry that was new.
  bool? _unread;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_unread != null) return;
    final s = context.read<SettingsController>();
    final no = context.read<GameController>().dailyPuzzle.no;
    _unread = s.notificationsUnread(no);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => s.markNotificationsSeen(no));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final s = context.watch<SettingsController>();
    final t = NumTheme.of(context);
    final stats = g.stats;

    // A push that does nothing when tapped isn't a notification, it's a label.
    // The daily one opens today's board; the rest are stats, so they open Stats.
    void openStats() => g.open(SheetOverlay.stats);

    final items = <Widget>[
      // The one live, unread push of the day — neutral, ritual copy.
      _Item(
        icon: Icons.today_rounded,
        color: t.accent,
        title: 'Today\'s board is ready',
        body: 'NUMLINK #${g.dailyPuzzle.no} · ${g.dailyPuzzle.dateLabel}',
        when: 'now',
        unread: _unread ?? false,
        onTap: () {
          g.close();
          openDailyBranching(context);
        },
      ),
    ];

    if (stats.streak > 0) {
      items.add(
        _Item(
          icon: Icons.local_fire_department_rounded,
          color: t.tileOrange,
          title: '${stats.streak}-day streak',
          body: 'Solve today to keep it going.',
          when: 'today',
          onTap: openStats,
        ),
      );
    }

    if (stats.playerLevel > 1) {
      items.add(
        _Item(
          icon: Icons.military_tech_rounded,
          color: t.hero,
          title: 'Level ${stats.playerLevel} reached',
          body: 'XP keeps stacking every solve.',
          when: 'recent',
          onTap: openStats,
        ),
      );
    }

    if (stats.wins > 0) {
      items.add(
        _Item(
          icon: Icons.emoji_events_rounded,
          color: t.star,
          title: '${stats.wins} dailies solved',
          body: 'Your all-time solve count.',
          when: 'log',
          onTap: openStats,
        ),
      );
    }

    // Also gated on the flag: the settings toggle is hidden, so socialNudges
    // keeps whatever value it defaults/persisted to and would still fire here.
    if (kSocialEnabled && s.socialNudges) {
      items.add(
        _Item(
          icon: Icons.groups_rounded,
          color: t.hero,
          title: 'A friend passed you',
          body: 'Play today to climb back up the board.',
          when: 'today',
        ),
      );
    }

    return BottomSheetShell(
      title: 'Notifications',
      onClose: g.close,
      children: [
        Text(
          'PUSHED FROM NUMLINK',
          style: Fonts.ui(
            size: 12,
            color: t.muted,
            weight: FontWeight.w700,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          entrance(items[i], on: !reducedMotion(context), index: i),
        ],
        const SizedBox(height: 14),
        Text(
          "That's everything for now.",
          style: Fonts.ui(size: 12, color: t.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.when,
    this.unread = false,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String when;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? tint(color, 0.10) : t.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: unread ? tint(color, 0.35) : t.border,
            width: 2,
          ),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Fonts.ui(
                            size: 14,
                            color: t.text,
                            weight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Text(
                        when,
                        style: Fonts.ui(size: 11, color: t.muted, height: 1),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: Fonts.ui(size: 12.5, color: t.muted, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
