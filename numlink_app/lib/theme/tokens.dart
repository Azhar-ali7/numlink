import 'package:flutter/material.dart';

/// Exact color tokens ported from the NUMLINK design handoff.
///
/// State colors follow the colorblind-safe Okabe–Ito palette and are always
/// paired with a shape or text label — never color alone.
@immutable
class NumTokens {
  const NumTokens({
    required this.bg,
    required this.surface,
    required this.elevated,
    required this.text,
    required this.muted,
    required this.border,
    required this.success,
    required this.progress,
  });

  final Color bg;
  final Color surface;
  final Color elevated;
  final Color text;
  final Color muted;
  final Color border;

  /// Primary / "solved" state color.
  final Color success;

  /// "Near / current" state color.
  final Color progress;

  /// Alternate colorblind success hue (orange).
  static const Color altSuccessOrange = Color(0xFFF5793A);

  NumTokens copyWith({Color? success}) => NumTokens(
        bg: bg,
        surface: surface,
        elevated: elevated,
        text: text,
        muted: muted,
        border: border,
        success: success ?? this.success,
        progress: progress,
      );

  static const NumTokens dark = NumTokens(
    bg: Color(0xFF121213),
    surface: Color(0xFF1E1E1E),
    elevated: Color(0xFF272727),
    text: Color(0xFFD7DADC),
    muted: Color(0xFF818488),
    border: Color(0xFF3A3A3C),
    success: Color(0xFF4C9FD6),
    progress: Color(0xFFE0A83A),
  );

  static const NumTokens light = NumTokens(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F7F8),
    elevated: Color(0xFFEEF0F2),
    text: Color(0xFF1A1A1B),
    muted: Color(0xFF787C7E),
    border: Color(0xFFD3D6DA),
    success: Color(0xFF0072B2),
    progress: Color(0xFFC77F00),
  );
}

/// Themed token lookup exposed via [Theme.of(context).extension].
@immutable
class NumTheme extends ThemeExtension<NumTheme> {
  const NumTheme(this.tokens);

  final NumTokens tokens;

  static NumTokens of(BuildContext context) =>
      Theme.of(context).extension<NumTheme>()!.tokens;

  @override
  NumTheme copyWith({NumTokens? tokens}) => NumTheme(tokens ?? this.tokens);

  @override
  NumTheme lerp(ThemeExtension<NumTheme>? other, double t) {
    if (other is! NumTheme) return this;
    return NumTheme(NumTokens(
      bg: Color.lerp(tokens.bg, other.tokens.bg, t)!,
      surface: Color.lerp(tokens.surface, other.tokens.surface, t)!,
      elevated: Color.lerp(tokens.elevated, other.tokens.elevated, t)!,
      text: Color.lerp(tokens.text, other.tokens.text, t)!,
      muted: Color.lerp(tokens.muted, other.tokens.muted, t)!,
      border: Color.lerp(tokens.border, other.tokens.border, t)!,
      success: Color.lerp(tokens.success, other.tokens.success, t)!,
      progress: Color.lerp(tokens.progress, other.tokens.progress, t)!,
    ));
  }
}

/// 12% / 14% tint of a color over transparent, matching the handoff's
/// `color-mix(in srgb, <c> N%, transparent)` fills.
Color tint(Color c, double pct) => c.withValues(alpha: pct);
