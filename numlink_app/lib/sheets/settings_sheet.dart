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
      title: 'Settings',
      onClose: g.close,
      children: [
        _Row(
          title: 'Appearance',
          subtitle: 'Near-black dark base, no pure black',
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
          title: 'Sound effects',
          subtitle: 'Taps, solve chime, and error tones',
          trailing: _Pill(value: s.sound, onTap: () => s.setSound(!s.sound)),
        ),
        _Row(
          title: 'Haptics',
          subtitle: 'Vibration feedback on supported devices',
          trailing: _Pill(value: s.haptics, onTap: () => s.setHaptics(!s.haptics)),
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
        const SizedBox(height: 12),
        Text(
          'NUMLINK #${g.puzzle.no} · State colors follow the Okabe–Ito palette '
          'and every state carries a shape or label, not color alone.',
          style: Fonts.ui(size: 12, color: t.muted, height: 1.5),
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
