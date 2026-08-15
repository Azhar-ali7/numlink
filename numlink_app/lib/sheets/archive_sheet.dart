import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'bottom_sheet_shell.dart';

/// Grid of past dailies to replay. Solved ones show a ✓; tapping loads the
/// puzzle (which closes the sheet). Replaying never touches the streak.
class ArchiveSheet extends StatelessWidget {
  const ArchiveSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final numbers = g.archiveNumbers;

    return BottomSheetShell(
      title: 'Archive',
      onClose: g.close,
      children: [
        Text('Replay any past daily — just for fun, no streak.',
            style: Fonts.ui(size: 13, color: t.muted, height: 1.3)),
        const SizedBox(height: 16),
        if (numbers.isEmpty)
          Text('No past puzzles yet — check back tomorrow.',
              style: Fonts.mono(size: 13, color: t.muted))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final no in numbers)
                _ArchiveTile(
                  no: no,
                  solved: g.stats.archiveSolved.contains(no),
                  onTap: () => g.startArchive(no),
                ),
            ],
          ),
      ],
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.no,
    required this.solved,
    required this.onTap,
  });

  final int no;
  final bool solved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: solved ? tint(t.success, 0.12) : t.surface,
          border: Border.all(
              color: solved ? t.success : t.border, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#$no',
                style: Fonts.mono(
                    size: 18,
                    color: solved ? t.success : t.text,
                    weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(solved ? 'SOLVED ✓' : 'PLAY',
                style: Fonts.ui(
                    size: 9,
                    color: t.muted,
                    weight: FontWeight.w700,
                    letterSpacing: 1,
                    height: 1)),
          ],
        ),
      ),
    );
  }
}
