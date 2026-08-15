import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/next_daily_countdown.dart';
import 'bottom_sheet_shell.dart';

class WinSheet extends StatelessWidget {
  const WinSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);

    return BottomSheetShell(
      title: 'Solved!',
      onClose: g.close,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHAIN COMPLETE',
              style: Fonts.ui(
                  size: 11,
                  color: t.success,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  height: 1)),
          const SizedBox(height: 4),
          Text('Solved!',
              style: Fonts.display(size: 38, color: t.text, height: 1)),
          const SizedBox(height: 8),
          Text(
            g.winSummary,
            style: Fonts.mono(size: 14, color: t.muted),
          ),
        ],
      ),
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(g.shareText(),
              style: Fonts.mono(size: 15, color: t.text, height: 1.5)),
        ),
        PrimaryButton(
          label: g.copied ? 'Copied to clipboard' : 'Share result',
          onTap: () {
            Clipboard.setData(ClipboardData(text: g.shareText()));
            g.markCopied();
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: SecondaryButton(
                    label: 'View stats',
                    onTap: () => g.open(SheetOverlay.stats))),
            const SizedBox(width: 10),
            Expanded(
                child: SecondaryButton(
                    label: 'Play again', onTap: g.playAgain)),
          ],
        ),
        if (g.mode == GameMode.daily) ...[
          const SizedBox(height: 16),
          const Center(child: NextDailyCountdown(center: true)),
        ],
      ],
    );
  }
}
