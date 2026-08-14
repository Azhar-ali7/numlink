import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Typography helpers.
///
/// - Display: Fraunces 400/700 (wordmark, sheet titles, "Solved!")
/// - UI: Space Grotesk 400/500/700 (labels, buttons, body)
/// - Numeric: Space Mono 400/700 — all changing numbers, always with
///   tabular figures so digits don't jitter.
class Fonts {
  const Fonts._();

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle display({
    required double size,
    Color? color,
    double weight = 700,
    double letterSpacing = 0,
    double height = 1,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight >= 700 ? FontWeight.w700 : FontWeight.w400,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle ui({
    required double size,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.4,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle mono({
    required double size,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1,
  }) =>
      GoogleFonts.spaceMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontFeatures: tabular,
      );
}

ThemeData buildTheme(NumTokens tokens, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: tokens.success,
    brightness: brightness,
  ).copyWith(
    surface: tokens.bg,
    primary: tokens.success,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: tokens.bg,
    colorScheme: scheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: GoogleFonts.spaceGroteskTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: tokens.text, displayColor: tokens.text),
    extensions: [NumTheme(tokens)],
  );
}
