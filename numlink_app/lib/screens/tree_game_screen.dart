import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/steiner.dart' as st;
import '../game/tree_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/operation_button.dart';
import '../widgets/radial_board.dart';
import '../widgets/ui.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TARGETS REACHED',
                    style: Fonts.ui(
                        size: 11,
                        color: t.muted,
                        weight: FontWeight.w700,
                        letterSpacing: 2,
                        height: 1)),
                const SizedBox(height: 4),
                Text('${g.reached}/$total',
                    style: Fonts.mono(
                        size: 40,
                        color: g.solved ? t.success : t.text,
                        weight: FontWeight.w700,
                        height: 0.95)),
              ],
            ),
          ),
          _Cell(
              label: 'MOVES',
              value: '${g.moves}/${g.puzzle.par}',
              color: overPar ? t.progress : t.text),
          const SizedBox(width: 8),
          _Cell(label: 'SHUFFLE', value: '${g.shufflesLeft}', color: t.text),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint(t.text, 0.05),
        border: Border.all(color: t.border, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Fonts.ui(
                  size: 9,
                  color: t.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 1.5,
                  height: 1)),
          const SizedBox(height: 3),
          Text(value,
              style:
                  Fonts.mono(size: 20, color: color, weight: FontWeight.w700)),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.border, width: 2)),
      ),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.75,
            children: g.hand.map((op) {
              final r = st.compute(g.selValue, op);
              final rem = g.remaining(op);
              return OperationButton(
                op: op,
                previewText: r == null ? '—' : '→ $r',
                remaining: rem,
                disabled: rem <= 0 || g.solved,
                shake: g.shakeOp == op.id,
                highlighted: g.hintGlow == op.id,
                onTap: () => g.apply(op),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _PadButton(
                      label: 'SHUFFLE·${g.shufflesLeft}',
                      onTap: g.shuffleHand)),
              const SizedBox(width: 10),
              Expanded(
                  child: _PadButton(
                      label: g.hintUsed ? 'HINT·0' : 'HINT·1',
                      onTap: g.hint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return HoverBorder(
      onTap: onTap,
      hoverColor: t.text,
      builder: (context, hover) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tint(t.text, hover ? 0.10 : 0.05),
          border: Border.all(color: hover ? t.text : t.border, width: 1.4),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: Fonts.ui(
                size: 12,
                color: t.text,
                weight: FontWeight.w700,
                letterSpacing: 1,
                height: 1)),
      ),
    );
  }
}
