import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/data/settings_controller.dart';
import 'package:numlink_app/services/feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The intro carousel is gated by SettingsController: open on first launch,
/// persisted-dismissed after the walkthrough, replayable via openTutorial().
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsController> make() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs: prefs, feedback: FeedbackService());
  }

  test('first launch opens the tutorial; dismiss persists across reloads',
      () async {
    SharedPreferences.setMockInitialValues({});

    final first = await make();
    expect(first.tutorialOpen, isTrue, reason: 'auto-show on first launch');

    first.dismissTutorial();
    expect(first.tutorialOpen, isFalse);

    // A fresh controller reading the same prefs must not re-open it.
    final reloaded = await make();
    expect(reloaded.tutorialOpen, isFalse, reason: 'tutorialSeen persisted');
  });

  test('seen users start closed but can replay', () async {
    SharedPreferences.setMockInitialValues({'tutorialSeen': true});

    final s = await make();
    expect(s.tutorialOpen, isFalse);

    s.openTutorial();
    expect(s.tutorialOpen, isTrue);

    s.dismissTutorial();
    expect(s.tutorialOpen, isFalse);
  });

  test('reminder time persists; the toggle defaults off at 9:00', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await make();
    expect(first.reminderOn, isFalse);
    expect(first.reminderHour, 9);
    expect(first.reminderMinute, 0);

    first.setReminderTime(20, 30);
    await first.setReminderOn(true); // no ReminderService here, so no prompt

    final reloaded = await make();
    expect(reloaded.reminderOn, isTrue);
    expect(reloaded.reminderHour, 20);
    expect(reloaded.reminderMinute, 30);
  });
}
