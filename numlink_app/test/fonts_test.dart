import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/theme/app_theme.dart';

/// google_fonts runs with runtime fetching off, so a weight that is not on disk
/// is not a fallback — it is an unhandled exception at paint time. That is what
/// shipped: a w600 call with no Nunito-SemiBold in assets/fonts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bundled = Directory('assets/fonts')
      .listSync()
      .map((f) => f.uri.pathSegments.last.replaceAll('.ttf', ''))
      .toSet();

  final names = {
    FontWeight.w400: 'Regular',
    FontWeight.w500: 'Medium',
    FontWeight.w600: 'SemiBold',
    FontWeight.w700: 'Bold',
    FontWeight.w800: 'ExtraBold',
  };

  test('every weight Fonts can be asked for is bundled', () {
    for (final w in FontWeight.values) {
      for (final style in [
        Fonts.ui(size: 12, weight: w),
        Fonts.numeric(size: 12, weight: w),
      ]) {
        final variant = names[style.fontWeight];
        expect(variant, isNotNull,
            reason: '$w snapped to ${style.fontWeight}, which has no variant');
        expect(bundled, contains('Nunito-$variant'),
            reason: '$w → Nunito-$variant is not in assets/fonts');
      }
    }
  });

  test('Baloo display weights are bundled too', () {
    for (final w in [400.0, 700.0, 800.0, 900.0]) {
      final style = Fonts.display(size: 12, weight: w);
      final variant = names[style.fontWeight];
      expect(bundled, contains('Baloo2-$variant'), reason: '$w → $variant');
    }
  });
}
