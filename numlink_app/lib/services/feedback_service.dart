import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Fires sound + haptic feedback for game events. Both channels are gated by
/// user settings and default OFF, so the app is silent until opted in.
class FeedbackService {
  FeedbackService();

  bool sound = false;
  bool haptics = false;

  // Players are created lazily on first sound so no platform resources are
  // touched until the user opts in (keeps tests / headless runs clean).
  AudioPlayer? _tap;
  AudioPlayer? _event;

  Future<void> _play(bool isTap, String file) async {
    if (!sound) return;
    try {
      final player = isTap
          ? (_tap ??= AudioPlayer())
          : (_event ??= AudioPlayer());
      await player.stop();
      await player.play(AssetSource('sfx/$file'), volume: 0.6);
    } catch (_) {
      // Audio is best-effort; never let it break gameplay.
    }
  }

  void onTap() {
    if (haptics) HapticFeedback.selectionClick();
    _play(true, 'tap.wav');
  }

  void onSolve() {
    if (haptics) HapticFeedback.heavyImpact();
    _play(false, 'win.wav');
  }

  void onIllegal() {
    if (haptics) HapticFeedback.mediumImpact();
    _play(false, 'error.wav');
  }

  void dispose() {
    _tap?.dispose();
    _event?.dispose();
  }
}
