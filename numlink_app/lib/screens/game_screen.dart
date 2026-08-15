import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/chain_node_widget.dart';
import '../widgets/heat_bar.dart';
import '../widgets/operation_button.dart';
import '../widgets/rolling_number.dart';
import '../widgets/ui.dart';

/// The core game screen: header · target/stats bar · scrollable chain · op pad.
/// Overlays (sheets, confetti, toast) are layered above by the app shell.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Column(
      children: [
        const _Header(),
        const _TargetBar(),
        Expanded(child: const _ChainArea()),
        const _OperationPad(),
      ],
    ).withBackground(t.bg);
  }
}

extension on Widget {
  Widget withBackground(Color c) => ColoredBox(color: c, child: this);
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconSquareButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Home',
              onTap: g.goHome),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.modeTitle,
                    style: Fonts.display(
                        size: 26, color: t.text, letterSpacing: -0.6, height: 1)),
                const SizedBox(height: 5),
                Text(g.modeSubtitle,
                    style: Fonts.mono(size: 11, color: t.muted, letterSpacing: 0.5)),
              ],
            ),
          ),
          IconSquareButton(
              icon: Icons.help_outline,
              semanticLabel: 'How to play',
              onTap: () => g.open(SheetOverlay.how)),
          const SizedBox(width: 8),
          IconSquareButton(
              icon: Icons.bar_chart,
              semanticLabel: 'Stats',
              onTap: () => g.open(SheetOverlay.stats)),
          const SizedBox(width: 8),
          IconSquareButton(
              icon: Icons.tune,
              semanticLabel: 'Settings',
              onTap: () => g.open(SheetOverlay.settings)),
        ],
      ),
    );
  }
}

class _TargetBar extends StatelessWidget {
  const _TargetBar();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GET TO',
                        style: Fonts.ui(
                            size: 11,
                            color: t.muted,
                            weight: FontWeight.w700,
                            letterSpacing: 2,
                            height: 1)),
                    const SizedBox(height: 4),
                    Text('${g.target}',
                        style: Fonts.mono(
                            size: 52, color: t.success, weight: FontWeight.w700, height: 0.95)),
                  ],
                ),
              ),
              _StatCell(label: 'MOVES', child: RollingNumber(
                g.moves,
                style: Fonts.mono(size: 22, color: t.text, weight: FontWeight.w700),
              )),
              // Zen drops par entirely; Timed swaps par for stage + a live clock.
              if (g.isTimed) ...[
                const SizedBox(width: 8),
                _StatCell(label: 'STAGE', child: Text('${g.stage}/${g.stageCount}',
                    style: Fonts.mono(size: 22, color: t.text, weight: FontWeight.w700))),
                const SizedBox(width: 8),
                _StatCell(label: 'TIME', child: Text(g.elapsedLabel,
                    style: Fonts.mono(size: 22, color: t.text, weight: FontWeight.w700))),
              ] else if (!g.isZen) ...[
                const SizedBox(width: 8),
                _StatCell(label: 'PAR', child: Text('${g.par}',
                    style: Fonts.mono(size: 22, color: t.text, weight: FontWeight.w700))),
              ],
            ],
          ),
          // Heat/proximity is score-pressure feedback — hidden in Zen.
          if (!g.isZen) ...[
            const SizedBox(height: 12),
            HeatBar(percent: g.heatPercent, heat: g.heat),
            const SizedBox(height: 6),
            Text(g.proximityText,
                style: Fonts.mono(size: 12, color: _heatColor(t, g.heat))),
          ],
        ],
      ),
    );
  }

  static Color _heatColor(NumTokens t, Heat h) => switch (h) {
        Heat.onTarget => t.success,
        Heat.near => t.progress,
        Heat.far => t.muted,
      };
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: t.border, width: 2),
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
          child,
        ],
      ),
    );
  }
}

class _ChainArea extends StatelessWidget {
  const _ChainArea();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final s = context.watch<SettingsController>();
    final t = NumTheme.of(context);
    final chain = g.chain;

    final children = <Widget>[];
    for (var i = 0; i < chain.length; i++) {
      final node = chain[i];
      final isLast = i == chain.length - 1;
      if (i > 0) children.add(OpEdge(label: node.opLabel));

      final NodeStyle style;
      if (i == 0) {
        style = NodeStyle(
            border: t.border, bg: Colors.transparent, numColor: t.text, badge: 'START');
      } else if (isLast && g.solved) {
        style = NodeStyle(
          border: t.success,
          bg: tint(t.success, 0.14),
          numColor: t.success,
          badge: s.highContrast ? 'TARGET · SOLVED ✓' : 'TARGET ✓',
        );
      } else if (isLast) {
        style = NodeStyle(
          border: t.progress,
          bg: tint(t.progress, 0.12),
          numColor: t.text,
          badge: s.highContrast ? 'YOU ARE HERE' : '',
        );
      } else {
        style = NodeStyle(
            border: t.border, bg: t.surface, numColor: t.muted);
      }

      children.add(ChainNodeWidget(
        key: ValueKey('node_$i'),
        value: node.value,
        style: style,
        animateIn: isLast && i > 0,
        rolling: isLast,
      ));
    }

    if (g.showTargetPlaceholder) {
      children.add(const OpEdge(dashed: true));
      children.add(ChainNodeWidget(
        value: g.target,
        style: NodeStyle(
          border: t.muted,
          bg: Colors.transparent,
          numColor: t.muted,
          badge: 'TARGET',
          dashed: true,
        ),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Column(children: children),
    );
  }
}

class _OperationPad extends StatelessWidget {
  const _OperationPad();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final ops = g.puzzle.ops;

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
            children: ops.map((op) {
              final r = g.preview(op);
              return OperationButton(
                op: op,
                previewText: r == null ? '—' : '→ $r',
                remaining: g.remaining(op),
                disabled: g.isDisabled(op),
                shake: g.shakeOpId == op.id,
                onTap: () => g.apply(op),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _TextButton(label: 'UNDO', onTap: g.undo)),
              const SizedBox(width: 10),
              Expanded(child: _TextButton(label: 'RESET', onTap: g.reset)),
              const SizedBox(width: 10),
              Expanded(
                  child: _TextButton(
                      label: 'STATS', onTap: () => g.open(SheetOverlay.stats))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});
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
          border: Border.all(color: hover ? t.text : t.border, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
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

/// The transient toast shown on illegal taps.
class GameToast extends StatelessWidget {
  const GameToast({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.elevated,
        border: Border.all(color: t.progress, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: Fonts.ui(size: 13, color: t.text, weight: FontWeight.w500, height: 1.2)),
    );
    if (!reducedMotion(context)) {
      toast = toast.animate().fadeIn(duration: Motion.toast).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: Motion.toast);
    }
    return toast;
  }
}
