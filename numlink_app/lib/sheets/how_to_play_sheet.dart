import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'bottom_sheet_shell.dart';

class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({super.key});

  static const _steps = [
    'Tap an operation (like ×3 or +7) to apply it to the current number.',
    'The chain branches outward. The highlighted node is where you are now.',
    '÷ only works when it divides evenly — no fractions allowed.',
    'Land exactly on the target to close the chain. Fewer moves = better.',
  ];

  @override
  Widget build(BuildContext context) {
    final g = context.read<GameController>();
    final t = NumTheme.of(context);

    return BottomSheetShell(
      title: 'How to play',
      onClose: g.close,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            'Chain operations to transform the start number into the target. '
            'Every tap adds a link. Match par to earn the birdie.',
            style: Fonts.ui(size: 15, color: t.text, height: 1.5),
          ),
        ),
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '${i + 1}',
                    style: Fonts.numeric(
                      size: 15,
                      color: t.success,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _steps[i],
                    style: Fonts.ui(size: 14, color: t.text, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Got it', onTap: g.close),
      ],
    );
  }
}
