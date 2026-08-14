import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/feedback_service.dart';

/// User settings. Defaults match the prototype: dark theme, high-contrast cues
/// ON, sound + haptics OFF.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.highContrast = true,
    this.orangeSuccess = false,
    this.sound = false,
    this.haptics = false,
  });

  final ThemeMode themeMode;
  final bool highContrast;
  final bool orangeSuccess;
  final bool sound;
  final bool haptics;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? highContrast,
    bool? orangeSuccess,
    bool? sound,
    bool? haptics,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        highContrast: highContrast ?? this.highContrast,
        orangeSuccess: orangeSuccess ?? this.orangeSuccess,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
      );
}

/// Holds live [AppSettings], persists changes to `shared_preferences`, and
/// keeps the [FeedbackService] in sync with the sound/haptics toggles.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required SharedPreferences prefs,
    required this.feedback,
  }) : _prefs = prefs {
    _settings = _load();
    _apply();
  }

  final SharedPreferences _prefs;
  final FeedbackService feedback;
  late AppSettings _settings;

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  bool get highContrast => _settings.highContrast;
  bool get orangeSuccess => _settings.orangeSuccess;
  bool get sound => _settings.sound;
  bool get haptics => _settings.haptics;

  AppSettings _load() => AppSettings(
        themeMode: (_prefs.getString('theme') ?? 'dark') == 'light'
            ? ThemeMode.light
            : ThemeMode.dark,
        highContrast: _prefs.getBool('highContrast') ?? true,
        orangeSuccess: _prefs.getBool('orangeSuccess') ?? false,
        sound: _prefs.getBool('sound') ?? false,
        haptics: _prefs.getBool('haptics') ?? false,
      );

  void _apply() {
    feedback.sound = _settings.sound;
    feedback.haptics = _settings.haptics;
  }

  void _update(AppSettings next) {
    _settings = next;
    _apply();
    notifyListeners();
    _prefs
      ..setString('theme', next.themeMode == ThemeMode.light ? 'light' : 'dark')
      ..setBool('highContrast', next.highContrast)
      ..setBool('orangeSuccess', next.orangeSuccess)
      ..setBool('sound', next.sound)
      ..setBool('haptics', next.haptics);
  }

  void setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(themeMode: mode));
  void setHighContrast(bool v) => _update(_settings.copyWith(highContrast: v));
  void setOrangeSuccess(bool v) => _update(_settings.copyWith(orangeSuccess: v));
  void setSound(bool v) => _update(_settings.copyWith(sound: v));
  void setHaptics(bool v) => _update(_settings.copyWith(haptics: v));
}
