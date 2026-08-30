import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/feedback_service.dart';

/// User settings. Defaults to the bright Duo-playful light theme, high-contrast
/// cues ON, sound + haptics OFF. (Dark stays available via the Settings toggle.)
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.highContrast = true,
    this.orangeSuccess = false,
    this.sound = false,
    this.haptics = false,
    this.reduceMotion = false,
    this.socialNudges = false,
    this.showResultPreviews = false,
    this.relaxedArms = false,
  });

  final ThemeMode themeMode;
  final bool highContrast;
  final bool orangeSuccess;
  final bool sound;
  final bool haptics;

  /// Player-forced reduce-motion (ORed with the OS `prefers-reduced-motion`).
  final bool reduceMotion;

  /// Opt-in competitive "friend passed you" nudges. Off by default.
  final bool socialNudges;

  /// Show the `→ result` preview under each operator tile. Off by default so
  /// players do the arithmetic themselves.
  final bool showResultPreviews;

  /// Lift the per-arm move cap to [kRelaxedBranchMax] so a branch can keep
  /// growing. Off by default: the cap is what makes a tier a tier.
  final bool relaxedArms;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? highContrast,
    bool? orangeSuccess,
    bool? sound,
    bool? haptics,
    bool? reduceMotion,
    bool? socialNudges,
    bool? showResultPreviews,
    bool? relaxedArms,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        highContrast: highContrast ?? this.highContrast,
        orangeSuccess: orangeSuccess ?? this.orangeSuccess,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        socialNudges: socialNudges ?? this.socialNudges,
        showResultPreviews: showResultPreviews ?? this.showResultPreviews,
        relaxedArms: relaxedArms ?? this.relaxedArms,
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
    _playerName = _prefs.getString('playerName') ?? 'Player';
    _notificationsSeen = _prefs.getInt('notificationsSeen') ?? 0;
    _tutorialSeen = _prefs.getBool('tutorialSeen') ?? false;
    _tutorialOpen = !_tutorialSeen; // auto-show the intro on first launch
  }

  final SharedPreferences _prefs;
  final FeedbackService feedback;
  late AppSettings _settings;

  // First-run intro carousel: [_tutorialSeen] is persisted once dismissed;
  // [_tutorialOpen] is transient visibility (also toggled by "Replay" in
  // Settings).
  late bool _tutorialSeen;
  bool _tutorialOpen = false;

  // The daily-puzzle number whose notifications the player has already read.
  // Every entry in the sheet is derived from the current daily, so one number
  // is the whole read state: a new daily makes the bell unread again.
  late int _notificationsSeen;

  /// Whether the bell should show its unread dot for daily puzzle [no].
  bool notificationsUnread(int no) => no != _notificationsSeen;

  /// Called when the player opens the notifications sheet.
  void markNotificationsSeen(int no) {
    if (no == _notificationsSeen) return;
    _notificationsSeen = no;
    _prefs.setInt('notificationsSeen', no);
    notifyListeners();
  }

  // Display name shown on Home ("Hi {name}") and the Profile avatar initial.
  late String _playerName;
  String get playerName => _playerName;

  /// Set the display name; blanks fall back to "Player". Persisted.
  void setPlayerName(String v) {
    _playerName = v.trim().isEmpty ? 'Player' : v.trim();
    _prefs.setString('playerName', _playerName);
    notifyListeners();
  }

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  bool get highContrast => _settings.highContrast;
  bool get orangeSuccess => _settings.orangeSuccess;
  bool get sound => _settings.sound;
  bool get haptics => _settings.haptics;
  bool get reduceMotion => _settings.reduceMotion;
  bool get socialNudges => _settings.socialNudges;
  bool get showResultPreviews => _settings.showResultPreviews;
  bool get relaxedArms => _settings.relaxedArms;
  bool get tutorialOpen => _tutorialOpen;

  /// True once the intro has ever been dismissed. Distinguishes a genuine
  /// first launch from a Settings "Replay" (drives the first-run Level 1 CTA).
  bool get tutorialSeen => _tutorialSeen;

  void openTutorial() {
    _tutorialOpen = true;
    notifyListeners();
  }

  void dismissTutorial() {
    _tutorialOpen = false;
    if (!_tutorialSeen) {
      _tutorialSeen = true;
      _prefs.setBool('tutorialSeen', true);
    }
    notifyListeners();
  }

  AppSettings _load() => AppSettings(
        themeMode: (_prefs.getString('theme') ?? 'light') == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light,
        highContrast: _prefs.getBool('highContrast') ?? true,
        orangeSuccess: _prefs.getBool('orangeSuccess') ?? false,
        sound: _prefs.getBool('sound') ?? false,
        haptics: _prefs.getBool('haptics') ?? false,
        reduceMotion: _prefs.getBool('reduceMotion') ?? false,
        socialNudges: _prefs.getBool('socialNudges') ?? false,
        showResultPreviews: _prefs.getBool('showResultPreviews') ?? false,
        relaxedArms: _prefs.getBool('relaxedArms') ?? false,
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
      ..setBool('haptics', next.haptics)
      ..setBool('reduceMotion', next.reduceMotion)
      ..setBool('socialNudges', next.socialNudges)
      ..setBool('showResultPreviews', next.showResultPreviews)
      ..setBool('relaxedArms', next.relaxedArms);
  }

  void setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(themeMode: mode));
  void setHighContrast(bool v) => _update(_settings.copyWith(highContrast: v));
  void setOrangeSuccess(bool v) => _update(_settings.copyWith(orangeSuccess: v));
  void setSound(bool v) => _update(_settings.copyWith(sound: v));
  void setHaptics(bool v) => _update(_settings.copyWith(haptics: v));
  void setReduceMotion(bool v) => _update(_settings.copyWith(reduceMotion: v));
  void setSocialNudges(bool v) => _update(_settings.copyWith(socialNudges: v));
  void setShowResultPreviews(bool v) =>
      _update(_settings.copyWith(showResultPreviews: v));
  void setRelaxedArms(bool v) => _update(_settings.copyWith(relaxedArms: v));
}
