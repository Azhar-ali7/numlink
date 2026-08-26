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
    required this.accent,
    required this.hero,
    required this.heroTwo,
    required this.tileOrange,
    required this.nav,
    required this.star,
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

  // Handoff accent palette (rose / indigo / amber / teal), themed so they swap
  // to the handoff's distinct dark values. Each is always paired with a label
  // or icon, never color-alone.
  final Color accent; // rose — header band + primary CTA + ÷-op hue
  final Color hero; // indigo — avatar / leaderboard disc / ×-op hue
  final Color heroTwo; // indigo tint — avatar gradient top stop
  final Color tileOrange; // warm orange — subtract op / warm tiles
  final Color nav; // dark "today's chain" card
  final Color star; // award star / notification dot / Σ hue

  /// Alternate colorblind success hue (Coral, `data-success="orange"`).
  static const Color altSuccessOrange = Color(0xFFEE7A4F);

  /// Soft card elevation, matching the handoff's `var(--shadow)` (warm on the
  /// cream theme, black on plum). Light vs dark is read off the base luminance,
  /// so it needs no separate constructor field.
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: bg.computeLuminance() < 0.3
              ? Colors.black.withValues(alpha: 0.38)
              : const Color(0x1F4A3620), // warm rgba(74,54,32,0.12)
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ];

  NumTokens copyWith({Color? success}) => NumTokens(
        bg: bg,
        surface: surface,
        elevated: elevated,
        text: text,
        muted: muted,
        border: border,
        success: success ?? this.success,
        progress: progress,
        accent: accent,
        hero: hero,
        heroTwo: heroTwo,
        tileOrange: tileOrange,
        nav: nav,
        star: star,
      );

  // Warm plum (default dark): a cozy aubergine base, softly raised surfaces,
  // teal as the primary "solved" action and amber for progress. Cloned from the
  // handoff prototype's dark `:root` tokens.
  static const NumTokens dark = NumTokens(
    bg: Color(0xFF241F27),
    surface: Color(0xFF2E2830),
    elevated: Color(0xFF38313F),
    text: Color(0xFFF1EAE1),
    muted: Color(0xFFA99FA6),
    border: Color(0xFF463E4B),
    success: Color(0xFF46BBAA), // teal
    progress: Color(0xFFF5B843), // amber
    accent: Color(0xFFF27FA1), // rose (dark)
    hero: Color(0xFF7D74F2), // indigo (dark)
    heroTwo: Color(0xFFB3AAF7),
    tileOrange: Color(0xFFF0A05E),
    nav: Color(0xFF17162A),
    star: Color(0xFFF7CD58),
  );

  // Learning-app cream (default): warm paper base, near-white cards, a rounded
  // playful palette. Teal is the primary "solved" action; amber drives
  // progress/near. Cloned from the handoff prototype's light `:root` tokens.
  static const NumTokens light = NumTokens(
    bg: Color(0xFFF4ECDF), // cream paper
    surface: Color(0xFFFBF6EC),
    elevated: Color(0xFFFFFFFF),
    text: Color(0xFF2B2622),
    muted: Color(0xFF6F6458),
    border: Color(0xFFE7DDCB),
    success: Color(0xFF237E72), // teal
    progress: Color(0xFFEFA42F), // amber
    accent: Color(0xFFEC6A8D), // rose
    hero: Color(0xFF6B61E6), // indigo
    heroTwo: Color(0xFFA99FF5),
    tileOrange: Color(0xFFEF8F4C),
    nav: Color(0xFF211F38),
    star: Color(0xFFF5C748),
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
      accent: Color.lerp(tokens.accent, other.tokens.accent, t)!,
      hero: Color.lerp(tokens.hero, other.tokens.hero, t)!,
      heroTwo: Color.lerp(tokens.heroTwo, other.tokens.heroTwo, t)!,
      tileOrange: Color.lerp(tokens.tileOrange, other.tokens.tileOrange, t)!,
      nav: Color.lerp(tokens.nav, other.tokens.nav, t)!,
      star: Color.lerp(tokens.star, other.tokens.star, t)!,
    ));
  }
}

/// 12% / 14% tint of a color over transparent, matching the handoff's
/// `color-mix(in srgb, <c> N%, transparent)` fills.
Color tint(Color c, double pct) => c.withValues(alpha: pct);
