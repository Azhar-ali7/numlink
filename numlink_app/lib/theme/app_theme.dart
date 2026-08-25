import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Typography helpers.
///
/// - Display: Baloo 2 700/800 — the rounded, chunky headline face (wordmark,
///   band headings, big numbers). Matches the handoff prototype.
/// - UI: Nunito 400/600/700/800 (labels, buttons, body) — rounded sans.
/// - Numeric: Nunito 800 with tabular figures — the handoff renders every
///   changing number (board digits, targets, scores, counts) in Nunito, not a
///   monospace face, so they stay on-brand and don't jitter.
class Fonts {
  const Fonts._();

  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle display({
    required double size,
    Color? color,
    double weight = 800,
    double letterSpacing = 0,
    double height = 1,
  }) =>
      GoogleFonts.baloo2(
        fontSize: size,
        // Baloo 2 ships 400–800; snap the requested weight to the nearest bold.
        fontWeight: weight >= 800
            ? FontWeight.w800
            : weight >= 700
                ? FontWeight.w700
                : FontWeight.w600,
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
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Changing numerals — Nunito with tabular figures (the handoff's number
  /// face; no monospace anywhere).
  static TextStyle numeric({
    required double size,
    Color? color,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0,
    double height = 1,
  }) =>
      GoogleFonts.nunito(
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
    textTheme: GoogleFonts.nunitoTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: tokens.text, displayColor: tokens.text),
    extensions: [NumTheme(tokens)],
  );
}
