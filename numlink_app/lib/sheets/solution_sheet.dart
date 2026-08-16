import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'bottom_sheet_shell.dart';

/// The reveal: the puzzle's one definite answer path, start → target, shown as
/// a sequence of `value —op→ value` steps. Unlocked only after enough failed
/// attempts (see [GameController.canReveal]).
class SolutionSheet extends StatelessWidget {
  const SolutionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.read<GameController>();
    final t = NumTheme.of(context);

    // Replay the answer path from the start to build the value at each step.
    final ops = g.answerPath;
    var value = g.puzzle.start;
    final steps = <Widget>[];
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final next = op.apply(value, cap: g.puzzle.cap) ?? value;
      steps.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('${i + 1}',
                  style: Fonts.mono(
                      size: 15, color: t.success, weight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Text('$value',
                style: Fonts.mono(size: 18, color: t.muted)),
            const SizedBox(width: 10),
            Text(op.label,
                style: Fonts.mono(
                    size: 16, color: t.progress, weight: FontWeight.w700)),
            const SizedBox(width: 10),
            Text('→ $next',
                style: Fonts.mono(
                    size: 18, color: t.text, weight: FontWeight.w700)),
          ],
        ),
      ));
      value = next;
    }

    return BottomSheetShell(
      title: 'Solution',
      onClose: g.close,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            'One way to get from ${g.puzzle.start} to ${g.puzzle.target} '
            'in ${ops.length} moves (par ${g.puzzle.par}).',
            style: Fonts.ui(size: 15, color: t.text, height: 1.5),
          ),
        ),
        ...steps,
        const SizedBox(height: 8),
        PrimaryButton(label: 'Back to puzzle', onTap: g.close),
      ],
    );
  }
}
