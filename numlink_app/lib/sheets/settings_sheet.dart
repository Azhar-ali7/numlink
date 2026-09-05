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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showMoreSettings(context),
          child: _Row(
            title: 'More settings',
            subtitle: 'About, help, and privacy',
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

/// "More settings": About, a real Help section (play, glossary, fixes) and the
/// privacy policy. Everything here is static copy, so it is one sheet with
/// headed sections rather than three routes.
/// (The handoff's Remove-Ads / Restore-Purchases rows are omitted: no IAP.)
void _showMoreSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = NumTheme.of(sheetContext);

      Widget head(String text) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 2),
        child: Text(
          text.toUpperCase(),
          style: Fonts.ui(
            size: 11,
            color: t.muted,
            weight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      );

      Widget item(String title, String body) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Fonts.ui(size: 15, color: t.text, weight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(body, style: Fonts.ui(size: 13, color: t.muted, height: 1.45)),
          ],
        ),
      );

      return BottomSheetShell(
        title: 'More settings',
        onClose: () => Navigator.of(sheetContext).pop(),
        titleStyleSize: 24,
        children: [
          item(
            'About NUMLINK',
            'Chain numbers together to reach every target in as few moves as '
                'possible. One new daily puzzle, an archive of past ones, a '
                'campaign, free play at four difficulties, and a weekend co-op '
                'board.',
          ),

          head('Help'),
          item(
            'Playing a board',
            'You start on one number. Tap an operator tile — ×3, +7, −4 — to '
                'apply it and grow the chain. Tap any number you have already '
                'reached to branch a new arm from there. Land exactly on a '
                'target to claim it; claim them all to solve the board.',
          ),
          item(
            'Arm',
            'One branch of the tree. Each arm holds only a few moves before it '
                'is full — tap an earlier number to start a new one. "Relaxed '
                'arms" in Settings lifts the cap.',
          ),
          item(
            'Par',
            'The move count a clean solve takes. Finishing at or under par is '
                'three stars; every move over costs one.',
          ),
          item(
            'Target',
            'A number you must land on exactly. The counter at the top left is '
                'how many you have reached.',
          ),
          item(
            'Shuffle & hint',
            'Shuffle deals a different set of operators that still solves the '
                'board. A hint glows the next useful operator. Both are limited '
                'per board, and easier tiers get more.',
          ),
          item(
            'Streaks and freezes',
            'Solving the daily on the day it appears extends your streak. Miss '
                'a day and a freeze is spent to cover it, one per missed day, '
                'if you have one. Replaying an archive board is just for fun — '
                'it never changes the streak.',
          ),
          item(
            'Playing against the clock',
            'On by default: every board gets a countdown scaled to its par, so '
                'a Kids board gets a gentler clock than a Hard one. Run out and '
                'the board freezes — no win, no streak. Turn it off in Settings '
                'to play untimed.',
          ),

          head('Stuck?'),
          item(
            'The move I want is rejected',
            'Three rules do most of it: ÷ only works when it divides evenly, a '
                'full arm needs you to branch from an earlier number, and a '
                'target counts only on an exact landing. The toast at the top '
                'of the board always names which one stopped you.',
          ),
          item(
            'I want the walkthrough again',
            'Settings → How to play replays the intro and then the on-board '
                'tour from the beginning.',
          ),
          item(
            'The daily reminder never arrives',
            'The reminder is a local notification, so it needs notification '
                'permission for NUMLINK in your system settings. Turn the '
                'Settings pill off and on again once permission is granted.',
          ),

          head('Privacy'),
          item(
            'The short version',
            'NUMLINK works entirely on this device. There are no accounts, no '
                'analytics, no ads, no trackers, and no third-party SDKs '
                'collecting anything about you.',
          ),
          item(
            'What is stored',
            'Your progress and preferences — streak, freezes, XP and level, '
                'stars, solved dailies, the display name you type, and every '
                'Settings toggle — are saved in this app\'s own storage on this '
                'device.',
          ),
          item(
            'What leaves the device',
            'Nothing, unless you press Share. Puzzles are generated on-device '
                'and fonts and sounds ship inside the app, so the game makes no '
                'network requests of its own. Sharing a result hands your text '
                'to the app you choose, and that app\'s privacy policy takes '
                'over from there.',
          ),
          item(
            'Notifications',
            'The daily reminder is scheduled locally by your device. No server '
                'is involved and no one is told whether you played.',
          ),
          item(
            'Children',
            'No personal information is collected from anyone, of any age. '
                'There is nothing to request, correct, or delete from a server, '
                'because there is no server.',
          ),
          item(
            'Deleting your data',
            'Deleting the app removes everything it saved. There is no copy '
                'anywhere else.',
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
