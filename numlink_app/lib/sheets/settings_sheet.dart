import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../flags.dart';
import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'bottom_sheet_shell.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.read<GameController>();
    final s = context.watch<SettingsController>();
    final t = NumTheme.of(context);

    return BottomSheetShell(
      title: 'Profile',
      onClose: g.close,
      fullScreen: true,
      children: [
        _ProfileHeader(level: g.playerLevel),
        const SizedBox(height: 8),
        _Row(
          title: 'Appearance',
          subtitle: 'Warm cream light base, cozy plum dark base',
          trailing: _Segmented(
            leftLabel: 'Dark',
            rightLabel: 'Light',
            leftSelected: s.themeMode == ThemeMode.dark,
            onLeft: () => s.setThemeMode(ThemeMode.dark),
            onRight: () => s.setThemeMode(ThemeMode.light),
          ),
        ),
        _Row(
          title: 'High-contrast cues',
          subtitle:
              'Colorblind-safe blue/orange with text labels on every state',
          trailing: _Pill(
            value: s.highContrast,
            onTap: () => s.setHighContrast(!s.highContrast),
          ),
        ),
        _Row(
          title: 'Orange for success',
          subtitle: 'Use orange instead of green for solved states',
          trailing: _Pill(
            value: s.orangeSuccess,
            onTap: () => s.setOrangeSuccess(!s.orangeSuccess),
          ),
        ),
        _Row(
          title: 'Show result previews',
          subtitle: 'Preview each operator\'s result under its tile',
          trailing: _Pill(
            value: s.showResultPreviews,
            onTap: () => s.setShowResultPreviews(!s.showResultPreviews),
          ),
        ),
        _Row(
          title: 'Play against the clock',
          subtitle:
              'Every board gets a countdown. The time scales with the '
              'difficulty, so a Kids board gets a gentler clock than a Hard '
              'one. Run out and the board freezes — no win, no streak.',
          trailing: _Pill(
            value: s.timedBoards,
            onTap: () => s.setTimedBoards(!s.timedBoards),
          ),
        ),
        _Row(
          title: 'Relaxed arms',
          subtitle:
              'An "arm" is one branch of the tree. Normally each can '
              'only take a few moves before it\'s full — this lifts that cap '
              'so any branch can keep growing. Par still counts, so scores '
              'suffer.',
          trailing: _Pill(
            value: s.relaxedArms,
            onTap: () => s.setRelaxedArms(!s.relaxedArms),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          // The row toggles; the time itself opens the platform time picker
          // rather than a hand-rolled one.
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: s.reminderHour,
                minute: s.reminderMinute,
              ),
            );
            if (picked != null) s.setReminderTime(picked.hour, picked.minute);
          },
          child: _Row(
            title: 'Daily reminder',
            subtitle:
                'A nudge at ${TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute).format(context)} '
                'when the new board is up — tap to change the time',
            trailing: _Pill(
              value: s.reminderOn,
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (await s.setReminderOn(!s.reminderOn)) return;
                // A denial used to leave the pill sitting there unmoved with no
                // explanation. SnackBar rather than GameToast: this is a sheet,
                // not a board, and there is no toast host up here.
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Turn on notifications for NUMLINK in system settings '
                      'to get the daily reminder.',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _Row(
          title: 'Sound effects',
          subtitle: 'Taps, solve chime, and error tones',
          trailing: _Pill(value: s.sound, onTap: () => s.setSound(!s.sound)),
        ),
        _Row(
          title: 'Haptics',
          subtitle: 'Vibration feedback on supported devices',
          trailing: _Pill(
            value: s.haptics,
            onTap: () => s.setHaptics(!s.haptics),
          ),
        ),
        _Row(
          title: 'Reduce motion',
          subtitle: 'Disable pop-ins, pulses, and the shake; states still cue',
          trailing: _Pill(
            value: s.reduceMotion,
            onTap: () => s.setReduceMotion(!s.reduceMotion),
          ),
        ),
        if (kSocialEnabled)
          _Row(
            title: 'Social nudges',
            subtitle: 'Occasional "a friend passed you" notifications',
            trailing: _Pill(
              value: s.socialNudges,
              onTap: () => s.setSocialNudges(!s.socialNudges),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            g.close();
            s.openTutorial();
          },
          child: _Row(
            title: 'How to play',
            subtitle: 'Replay the intro, then the board tour',
            trailing: Icon(Icons.chevron_right, color: t.muted),
          ),
        ),
        for (final (title, subtitle, items) in [
          ('About', 'What NUMLINK is, and how you progress', _about),
          ('Help', 'Rules, scoring, and why a move gets rejected', _help),
          ('Privacy', 'What is stored, and what never leaves', _privacy),
        ])
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showInfoSheet(context, title, items),
            child: _Row(
              title: title,
              subtitle: subtitle,
              trailing: Icon(Icons.chevron_right, color: t.muted),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'NUMLINK #${g.dailyPuzzle.no} · State colors follow the Okabe–Ito palette '
          'and every state carries a shape or label, not color alone.',
          style: Fonts.ui(size: 12, color: t.muted, height: 1.5),
        ),
      ],
    );
  }
}

/// The static copy behind the About / Help / Privacy rows, as (title, body)
/// pairs. Data, not widgets — [_showInfoSheet] renders all three the same way.
///
/// Every number here is the one the code actually uses (kTiers, kCampaign,
/// starsFor, GameStats.freezeMilestones, the tree_controller reject toasts).
/// If you retune those, retune this.
/// (The handoff's Remove-Ads / Restore-Purchases rows are omitted: no IAP.)
const _about = <(String, String)>[
  (
    'The game',
    'Every board gives you a starting number, a handful of operator tiles and '
        'a ring of targets. Apply tiles to grow a branching chain and land '
        'exactly on every target.',
  ),
  (
    'Where to play',
    'A new Daily Puzzle each day; the Archive, which holds every daily since '
        'launch; a 24-level Campaign that ramps from one-move Kids boards to '
        'four-deep Expert ones; and Free Play at Kids, Easy, Normal or Expert.',
  ),
  (
    'Progress',
    'Solving earns XP (10 a win, +5 for every move under par) which raises '
        'your level. Campaign levels also score 1-3 stars, and eight badges — '
        'First Link through Ladder Climber — unlock as you go. Stats has the '
        'lot.',
  ),
  (
    'Boards are generated, not authored',
    'Each board is built solution-first from a seed, so it is always solvable, '
        'and the same puzzle number is the same board for everyone.',
  ),
];

const _help = <(String, String)>[
  (
    'Playing a board',
    'Tap an operator tile — ×3, +7, −4 — to apply it to the number you are on. '
        'To branch, tap any number already on the board and apply a tile from '
        'there. Land exactly on a target to claim it; claim them all to solve '
        'the board.',
  ),
  (
    'Tiles run out',
    'Each tile carries a limited number of uses. When they are spent, that '
        'tile is done for the board — which is why the same +7 cannot carry you '
        'all the way round.',
  ),
  (
    'Arms',
    'An arm is one branch of the chain, and it can only run so deep: 1 move on '
        'Kids, 2 on Easy, 3 on Normal, 4 on Expert. Hit the limit and you '
        'branch from an earlier number instead. "Relaxed arms" in Settings '
        'lifts the cap if you would rather not think about it.',
  ),
  (
    'Par and stars',
    'Par is what a clean solve takes. Par or better is three stars, one over is '
        'two, anything finished is one. Under par also pays +5 XP a move.',
  ),
  (
    'Shuffle and hint',
    'Shuffle deals a different set of tiles that still solves the board; a hint '
        'points at the next useful tile. Both are limited and easier tiers get '
        'more: Kids has 3 shuffles and 3 hints, Easy 3 and 2, Normal 2 and 1, '
        'Expert 2 and 1.',
  ),
  (
    'The operators',
    '+ − × arrive first. ÷ joins on Easy, % (remainder) on Normal along with Σ '
        '(add the digits), and Expert adds √. ÷ and √ only work when they come '
        'out whole.',
  ),
  (
    'Streaks and freezes',
    'Solving the daily on its own day extends your streak. Reaching a 3-, 7-, '
        '14- or 30-day streak banks a freeze (two at most), and a missed day '
        'spends one freeze to keep the streak alive. Replaying an archive board '
        'is just for fun — it never touches the streak.',
  ),
  (
    'The clock',
    'On by default: every board counts down from a budget scaled to its par, so '
        'a Kids board gets a gentler clock than an Expert one. Run out and the '
        'board freezes — no win, no streak, and Try again deals a fresh board. '
        'Turn "Play against the clock" off in Settings to play untimed.',
  ),
  (
    'Why a move gets rejected',
    'The toast at the top of the board always names the reason, and it is '
        'usually one of five: the tile is out of uses, the arm is at its move '
        'limit, ÷ would not divide evenly (or √ is not a perfect square), the '
        'result is already on the board, or the move leaves the number '
        'unchanged.',
  ),
  (
    'Want the walkthrough again?',
    'Settings, then How to play, replays the intro and then the on-board tour '
        'from the beginning.',
  ),
  (
    'The daily reminder never arrives',
    'It is a local notification, so it needs notification permission for '
        'NUMLINK in your system settings. Once permission is granted, switch '
        'the Settings pill off and on again.',
  ),
];

const _privacy = <(String, String)>[
  (
    'The short version',
    'NUMLINK runs entirely on this device. No account, no sign-in, no '
        'analytics, no ads, no trackers, and no third-party SDK collecting '
        'anything about you.',
  ),
  (
    'What is stored',
    'Your progress and preferences — streak, freezes, XP and level, campaign '
        'stars, which dailies you solved, the display name you type, and every '
        'Settings toggle — are saved in this app\'s own storage on this device.',
  ),
  (
    'What leaves the device',
    'Nothing. Boards are generated on-device from a seed, and the fonts and '
        'sounds ship inside the app, so the game makes no network requests at '
        'all. Copy on the win sheet puts your result text on this device\'s '
        'clipboard and stops there — where it goes next is up to you.',
  ),
  (
    'Notifications',
    'The daily reminder is scheduled locally by your device at the time you '
        'pick. No server is involved and no one is told whether you played.',
  ),
  (
    'Children',
    'No personal information is collected from anyone, of any age. There is '
        'nothing to request, correct or delete from a server, because there is '
        'no server.',
  ),
  (
    'Deleting your data',
    'Deleting the app removes everything it saved. There is no copy anywhere '
        'else.',
  ),
];

/// One bottom sheet of headed paragraphs.
void _showInfoSheet(
  BuildContext context,
  String title,
  List<(String, String)> items,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = NumTheme.of(sheetContext);
      return BottomSheetShell(
        title: title,
        onClose: () => Navigator.of(sheetContext).pop(),
        titleStyleSize: 24,
        children: [
          for (final (heading, body) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: Fonts.ui(
                      size: 15,
                      color: t.text,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: Fonts.ui(size: 13, color: t.muted, height: 1.45),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader({required this.level});

  final int level;

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  bool _editing = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _start(String name) {
    _ctrl.text = name;
    setState(() => _editing = true);
  }

  void _save() {
    context.read<SettingsController>().setPlayerName(_ctrl.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final name = context.watch<SettingsController>().playerName;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.heroTwo, t.hero],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            name.characters.first.toUpperCase(),
            style: Fonts.display(size: 24, color: Colors.white, weight: 800),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_editing)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        onSubmitted: (_) => _save(),
                        style: Fonts.ui(
                          size: 16,
                          color: t.text,
                          weight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Your name',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: t.border, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: t.border, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _save,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: t.success,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              else
                GestureDetector(
                  onTap: () => _start(name),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: Fonts.display(
                            size: 20,
                            color: t.text,
                            weight: 700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit_outlined, size: 16, color: t.muted),
                    ],
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                'Level ${widget.level} · Earn XP to level up',
                style: Fonts.ui(
                  size: 12,
                  color: t.muted,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Fonts.ui(
                    size: 15,
                    color: t.text,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Fonts.ui(size: 12, color: t.muted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    Widget seg(String label, bool selected, VoidCallback onTap, bool border) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: border
                ? Border(right: BorderSide(color: t.border, width: 2))
                : null,
          ),
          child: Text(
            label,
            style: Fonts.ui(
              size: 12,
              color: selected ? t.success : t.muted,
              weight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.border, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(leftLabel, leftSelected, onLeft, true),
          seg(rightLabel, !leftSelected, onRight, false),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 30,
        decoration: BoxDecoration(
          color: value ? t.success : t.border,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: Motion.micro,
          curve: Motion.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
