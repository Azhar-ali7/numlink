import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
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
          trailing: _Pill(value: s.highContrast, onTap: () => s.setHighContrast(!s.highContrast)),
        ),
        _Row(
          title: 'Show result previews',
          subtitle: 'Preview each operator\'s result under its tile',
          trailing: _Pill(
              value: s.showResultPreviews,
              onTap: () => s.setShowResultPreviews(!s.showResultPreviews)),
        ),
        _Row(
          title: 'Sound effects',
          subtitle: 'Taps, solve chime, and error tones',
          trailing: _Pill(value: s.sound, onTap: () => s.setSound(!s.sound)),
        ),
        _Row(
          title: 'Haptics',
          subtitle: 'Vibration feedback on supported devices',
          trailing: _Pill(value: s.haptics, onTap: () => s.setHaptics(!s.haptics)),
        ),
        _Row(
          title: 'Reduce motion',
          subtitle: 'Disable pop-ins, pulses, and the shake; states still cue',
          trailing:
              _Pill(value: s.reduceMotion, onTap: () => s.setReduceMotion(!s.reduceMotion)),
        ),
        _Row(
          title: 'Social nudges',
          subtitle: 'Occasional "a friend passed you" notifications',
          trailing:
              _Pill(value: s.socialNudges, onTap: () => s.setSocialNudges(!s.socialNudges)),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            g.close();
            s.openTutorial();
          },
          child: _Row(
            title: 'How to play',
            subtitle: 'Replay the intro walkthrough',
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

/// Lightweight "More settings" info sheet — About / Help / Privacy blurbs.
/// (The handoff's Remove-Ads / Restore-Purchases rows are omitted: no IAP.)
void _showMoreSettings(BuildContext context) {
  final t = NumTheme.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.elevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) {
      Widget item(String title, String body) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Fonts.ui(
                        size: 15, color: t.text, weight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body,
                    style: Fonts.ui(size: 13, color: t.muted, height: 1.4)),
              ],
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('More settings',
                  style: Fonts.display(size: 24, color: t.text, weight: 700)),
              const SizedBox(height: 6),
              item('About NUMLINK',
                  'Chain numbers together to reach each target in as few moves as possible.'),
              item('Help',
                  'Tap operators to branch from any reached number. Stuck? Replay the walkthrough from How to play.'),
              item('Privacy',
                  'Your progress lives on this device. Nothing is shared without your say-so.'),
            ],
          ),
        ),
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
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [NumTokens.heroTwo, NumTokens.hero],
            ),
          ),
          alignment: Alignment.center,
          child: Text(name.characters.first.toUpperCase(),
              style: Fonts.display(size: 24, color: Colors.white, weight: 800)),
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
                            size: 16, color: t.text, weight: FontWeight.w700),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Your name',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.check,
                            size: 18, color: Colors.white),
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
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: Fonts.display(
                                size: 20, color: t.text, weight: 700)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit_outlined, size: 16, color: t.muted),
                    ],
                  ),
                ),
              const SizedBox(height: 3),
              Text('Level ${widget.level} · Earn XP to level up',
                  style: Fonts.ui(size: 12, color: t.muted, weight: FontWeight.w700)),
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
                Text(title,
                    style: Fonts.ui(
                        size: 15, color: t.text, weight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Fonts.ui(size: 12, color: t.muted, height: 1.35)),
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
          child: Text(label,
              style: Fonts.ui(
                  size: 12,
                  color: selected ? t.success : t.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 0.5,
                  height: 1)),
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
