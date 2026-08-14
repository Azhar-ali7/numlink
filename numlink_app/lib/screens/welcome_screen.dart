import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../widgets/streak_flame.dart';

/// Branded landing shown before play: mini chain preview, wordmark, streak +
/// puzzle stat cards, and the launch buttons.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final reduce = reducedMotion(context);

    final Widget preview = _PopIn(
      enabled: !reduce,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PreviewNode(
              value: '${g.puzzle.start}', color: t.text, border: t.border),
          _Connector(color: t.border),
          _DashedQ(color: t.muted),
          _Connector(color: t.border),
          _PreviewNode(
            value: '${g.puzzle.target}',
            color: t.success,
            border: t.success,
            bg: tint(t.success, 0.12),
          ),
        ],
      ),
    );

    // One centered column (content + CTAs together). No Expanded / no
    // IntrinsicHeight, so it can never overflow: on tall screens the block
    // centers, on short screens the whole thing scrolls.
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(child: preview),
        const SizedBox(height: 26),
        Text('NUMLINK',
            style: Fonts.display(
                size: 64, color: t.text, letterSpacing: -1.5, height: 0.92)),
        const SizedBox(height: 12),
        SizedBox(
          width: 300,
          child: Text(
            'Chain the operations. Turn the start number into the target in '
            'as few moves as you can.',
            style: Fonts.ui(size: 16, color: t.muted, height: 1.4),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${g.stats.streak}',
                label: 'DAY STREAK',
                valueColor: t.success,
                flame: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '#${g.puzzle.no}',
                label: g.puzzle.dateLabel,
                valueColor: t.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _WelcomeButton(
          label: "Play today's puzzle",
          filled: true,
          onTap: g.startGame,
        ),
        const SizedBox(height: 12),
        _WelcomeButton(
          label: 'How to play',
          filled: false,
          onTap: () => g.open(SheetOverlay.how),
        ),
        const SizedBox(height: 32),
      ],
    );

    // Rendered fully opaque (no entrance opacity that could leave the screen
    // blank); the preview pop above is the entrance flourish. Wrapped in
    // Positioned.fill by the app shell, so this must NOT return a Positioned.
    return ColoredBox(
      color: t.bg,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(child: content),
          ),
        ),
      ),
    );
  }
}

/// One-shot overshoot scale-in using a layout-neutral [Transform] so it never
/// interferes with intrinsic-height measurement (unlike a wrapping animation
/// widget that doesn't forward intrinsics).
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Motion.overshoot,
      child: child,
      builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
    );
  }
}

class _PreviewNode extends StatelessWidget {
  const _PreviewNode({
    required this.value,
    required this.color,
    required this.border,
    this.bg,
  });

  final String value;
  final Color color;
  final Color border;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: bg ?? t.surface,
        border: Border.all(color: border, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(value,
          style: Fonts.mono(size: 34, color: color, weight: FontWeight.w700)),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 2, height: 14, color: color);
}

class _DashedQ extends StatelessWidget {
  const _DashedQ({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('?',
          style: Fonts.mono(size: 12, color: color, weight: FontWeight.w700)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
    this.flame = false,
  });

  final String value;
  final String label;
  final Color valueColor;
  final bool flame;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final streak = int.tryParse(value) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: t.border, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(value,
                  style: Fonts.mono(
                      size: 24, color: valueColor, weight: FontWeight.w700)),
              if (flame && streak > 0) ...[
                const SizedBox(width: 5),
                StreakFlame(streak: streak, color: valueColor, size: 18),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Fonts.ui(
                  size: 10,
                  color: t.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 1,
                  height: 1)),
        ],
      ),
    );
  }
}

class _WelcomeButton extends StatefulWidget {
  const _WelcomeButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_WelcomeButton> createState() => _WelcomeButtonState();
}

class _WelcomeButtonState extends State<_WelcomeButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: widget.filled ? 18 : 14),
          decoration: BoxDecoration(
            color: widget.filled
                ? t.success.withValues(alpha: _hover ? 0.9 : 1)
                : Colors.transparent,
            border: widget.filled
                ? null
                : Border.all(
                    color: _hover ? t.success : t.border, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: Fonts.ui(
              size: widget.filled ? 17 : 14,
              color: widget.filled ? Colors.white : t.text,
              weight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
