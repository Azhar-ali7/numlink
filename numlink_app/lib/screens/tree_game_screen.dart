import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../game/steiner.dart' show compute;
import '../game/tree_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/operation_button.dart';
import '../widgets/radial_board.dart';

/// Branching-tree game screen: status bar · radial board · op pad.
/// Reads a [TreeController] from the widget tree.
class TreeGameScreen extends StatelessWidget {
  const TreeGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return ColoredBox(
      color: t.bg,
      child: const Column(
        children: [
          _StatusBar(),
          Expanded(child: RadialBoard()),
          _OpPad(),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<TreeController>();
    final t = NumTheme.of(context);
    final total = g.puzzle.targets.length;
    final overPar = g.moves > g.puzzle.par;
    final left = g.armLeft;
    final armLabel = left == 0
        ? 'arm full'
        : (left == 1 ? '1 left on this arm' : '$left left on this arm');
    final armColor = left <= 1 ? t.accent : (left <= 2 ? t.progress : t.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // left: reached/total TARGETS
          Text('${g.reached}/$total',
              style: Fonts.numeric(
                  size: 34,
                  color: g.solved ? t.success : t.text,
                  weight: FontWeight.w800,
                  height: 1)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text('TARGETS',
                style: Fonts.ui(
                    size: 10,
                    color: t.muted,
                    weight: FontWeight.w800,
                    letterSpacing: 1.5)),
          ),
          const Spacer(),
          // right: moves/par · N left on this arm
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${g.moves}/${g.puzzle.par}',
                  style: Fonts.numeric(
                      size: 22,
                      color: overPar ? t.progress : t.text,
                      weight: FontWeight.w800,
                      height: 1)),
              const SizedBox(height: 4),
              Text(armLabel,
                  style: Fonts.ui(
                      size: 11, color: armColor, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpPad extends StatelessWidget {
  const _OpPad();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<TreeController>();
    final t = NumTheme.of(context);
    // Settings may be absent in isolated widget tests; default previews off.
    bool showPreviews = false;
    try {
      showPreviews = context.select<SettingsController, bool>(
          (s) => s.showResultPreviews);
    } on ProviderNotFoundException {
      showPreviews = false;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border, width: 2)),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // Shorter tiles (taller cells) when the preview line is showing.
        childAspectRatio: showPreviews ? 1.8 : 2.1,
        children: g.hand.map((op) {
          final rem = g.remaining(op);
          // Result previews are gated behind the "Show result previews" setting
          // (off by default per the handoff); shuffle/hint live in the header.
          String preview = '';
          if (showPreviews) {
            final r = compute(g.selValue, op);
            preview = r == null ? '—' : '→ $r';
          }
          return OperationButton(
            op: op,
            previewText: preview,
            remaining: rem,
            disabled: rem <= 0 || g.solved,
            shake: g.shakeOp == op.id,
            highlighted: g.hintGlow == op.id,
            onTap: () => g.apply(op),
          );
        }).toList(),
      ),
    );
  }
}
