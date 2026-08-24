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

  // Playful category accents (Duolingo-ish) for the mode grid / tiles. Static —
  // same in light & dark so tiles keep a consistent identity; always paired with
  // a label or icon, never color-alone.
  static const Color accentBlue = Color(0xFF1CB0F6); // macaw
  static const Color accentPurple = Color(0xFFCE82FF); // beetle
  static const Color accentOrange = Color(0xFFFF9600); // fox
  static const Color accentPink = Color(0xFFFF4B8B); // flamingo
  static const Color danger = Color(0xFFFF4B4B); // cardinal (illegal/toast)

  // Banded "learning-app" home palette (cloned verbatim from the handoff
  // prototype `design-handoff-current/NUMLINK.dc.html`). Home-only; each is
  // always paired with a label or icon. White text sits on the pink/teal bands
  // (bold, AA-large). The orange orbit band and the amber gauge fill reuse the
  // themed `progress` token; the teal gauge band reuses `success`.
  static const Color accent = Color(0xFFEC6A8D); // pink header band + primary CTA
  static const Color hero = Color(0xFF6B61E6); // avatar / leaderboard disc
  static const Color heroTwo = Color(0xFFA99FF5); // avatar gradient top stop
  static const Color nav = Color(0xFF211F38); // dark "today's chain" card
  static const Color star = Color(0xFFF5C748); // award star / notification dot

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
  );

  // Neon accents for glows/gradients (electric on the deep base).
  static const Color neonBlue = Color(0xFF37C3FF);
  static const Color neonPurple = Color(0xFFB47CFF);

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
