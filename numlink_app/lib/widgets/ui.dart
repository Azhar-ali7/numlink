import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// The handoff's `cardIn` keyframe: fade + rise + a hair of scale, staggered by
/// [index] down a list. Returns [child] untouched when [on] is false (reduced
/// motion), so it stays a no-op in tests. One place so the chain isn't repeated.
Widget entrance(Widget child, {required bool on, int index = 0}) {
  if (!on) return child;
  return child
      .animate(delay: Duration(milliseconds: index * 60))
      .fadeIn(duration: Motion.standard, curve: Motion.easeOut)
      .moveY(
        begin: 16,
        end: 0,
        duration: Motion.standard,
        curve: Motion.easeOut,
      )
      .scaleXY(
        begin: 0.97,
        end: 1,
        duration: Motion.standard,
        curve: Motion.easeOut,
      );
}

/// A 40×40 bordered icon button (header actions, sheet close). Hover/pressed
/// highlights the border in [hoverColor] (defaults to success). Hover state
/// comes from [HoverBorder] — no duplicated MouseRegion bookkeeping.
class IconSquareButton extends StatelessWidget {
  const IconSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final hi = hoverColor ?? t.success;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: HoverBorder(
        onTap: onTap,
        builder: (context, hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          // 44 minimum tap target; the glyph stays 20.
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: hover ? hi : t.border, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 20, color: t.text),
        ),
      ),
    );
  }
}

/// A tappable widget whose border highlights on hover.
class HoverBorder extends StatefulWidget {
  const HoverBorder({super.key, required this.builder, this.onTap});

  final Widget Function(BuildContext context, bool hover) builder;
  final VoidCallback? onTap;

  @override
  State<HoverBorder> createState() => _HoverBorderState();
}

class _HoverBorderState extends State<HoverBorder> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: widget.builder(context, _hover),
      ),
    );
  }
}
