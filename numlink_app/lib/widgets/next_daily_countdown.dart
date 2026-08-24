import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// "NEXT PUZZLE IN 12:34:56" — counts down to the next local midnight, when a
/// new daily unlocks. Self-contained 1s timer; no controller wiring needed.
class NextDailyCountdown extends StatefulWidget {
  const NextDailyCountdown({super.key, this.center = false, this.color});

  final bool center;

  /// Overrides the text color (e.g. white on the teal player bar). The label
  /// draws at 80% of this, the value at full; falls back to the theme tokens.
  final Color? color;

  @override
  State<NextDailyCountdown> createState() => _NextDailyCountdownState();
}

class _NextDailyCountdownState extends State<NextDailyCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _remaining {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final d = tomorrow.difference(now);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Row(
      mainAxisAlignment:
          widget.center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Text('NEXT PUZZLE IN ',
            style: Fonts.ui(
                size: 11,
                color: (widget.color ?? t.muted)
                    .withValues(alpha: widget.color != null ? 0.8 : 1),
                weight: FontWeight.w700,
                letterSpacing: 1.5,
                height: 1)),
        Text(_remaining,
            style: Fonts.mono(
                size: 12,
                color: widget.color ?? t.text,
                weight: FontWeight.w700)),
      ],
    );
  }
}
