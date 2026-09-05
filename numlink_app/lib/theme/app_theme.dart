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
        // Only Bold/ExtraBold are bundled (see [_nunito] on why a miss throws).
        fontWeight: weight >= 800 ? FontWeight.w800 : FontWeight.w700,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Snap to a weight actually bundled in assets/fonts. google_fonts has
  /// runtime fetching off (App Sandbox blocks the socket), so asking for an
  /// unbundled weight — w600, with only 400/500/700/800 shipped — throws an
  /// unhandled exception at paint time instead of falling back.
  static FontWeight _nunito(FontWeight w) => switch (w.value) {
    <= 400 => FontWeight.w400,
    <= 600 => FontWeight.w500,
    <= 700 => FontWeight.w700,
    _ => FontWeight.w800,
  };

  static TextStyle ui({
    required double size,
    Color? color,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
    double height = 1.4,
  }) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: _nunito(weight),
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
        fontWeight: _nunito(weight),
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
