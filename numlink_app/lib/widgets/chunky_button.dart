import 'package:flutter/material.dart';

/// The signature "Duo Playful" button: a filled face sitting on a darker base,
/// so it reads as a chunky 3D key. Pressing collapses the base, dropping the
/// face down onto it — the classic Duolingo/Candy-Crush tactile press.
///
/// Layout-safe: the only thing that changes on press is `depth` px of bottom
/// padding (~5px, ~70ms), so it can't overlap siblings or cause reflow issues.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    this.baseColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.radius = 18,
    this.depth = 5,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Face color. The base (shadow) defaults to a darkened shade of it.
  final Color color;
  final Color? baseColor;
  final EdgeInsets padding;
  final double radius;

  /// Thickness of the 3D base under the face.
  final double depth;
  final bool enabled;

  static Color darken(Color c, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.enabled && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? ChunkyButton.darken(widget.color);
    final radius = BorderRadius.circular(widget.radius);
    final down = _pressed && widget.enabled;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: (_) => _set(true),
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            curve: Curves.easeOut,
            decoration: BoxDecoration(color: base, borderRadius: radius),
            padding: EdgeInsets.only(bottom: down ? 0 : widget.depth),
            child: Container(
              decoration: BoxDecoration(color: widget.color, borderRadius: radius),
              padding: widget.padding,
              alignment: Alignment.center,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
