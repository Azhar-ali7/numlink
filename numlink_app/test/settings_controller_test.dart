import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/data/settings_controller.dart';
import 'package:numlink_app/services/feedback_service.dart';
import 'package:numlink_app/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the OS notification plugin. A subclass, not a generated mock:
/// two overrides beat mockito + build_runner + a codegen step for this.
class _FakeReminders extends ReminderService {
  _FakeReminders({this.granted = true, this.throwOnRequest = false});
  final bool granted, throwOnRequest;

  /// Every schedule() the controller asked for, in order.
  final calls = <({bool on, int hour, int minute})>[];

  @override
  Future<bool> requestPermission() async {
    if (throwOnRequest) throw ArgumentError('macOS settings must be set');
    return granted;
  }

  @override
  Future<void> schedule({
    required bool on,
    required int hour,
    required int minute,
  }) async =>
      calls.add((on: on, hour: hour, minute: minute));
}

/// The intro carousel is gated by SettingsController: open on first launch,
/// persisted-dismissed after the walkthrough, replayable via openTutorial().
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsController> make([ReminderService? reminders]) async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(
      prefs: prefs,
      feedback: FeedbackService(),
      reminders: reminders,
    );
  }

  group('setReminderOn talks to the OS before it flips', () {
    test('granted: flips, persists, and schedules at the stored time',
        () async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeReminders();
      final s = await make(fake);
      s.setReminderTime(20, 30);
      fake.calls.clear(); // the time change reschedules too

      expect(await s.setReminderOn(true), isTrue);
      expect(s.reminderOn, isTrue);
      expect(fake.calls, [(on: true, hour: 20, minute: 30)]);

      expect(await s.setReminderOn(false), isTrue);
      expect(fake.calls.last.on, isFalse);
    });

    test('denied: reports false and leaves the toggle where it was', () async {
      SharedPreferences.setMockInitialValues({'reminderOn': false});
      final fake = _FakeReminders(granted: false);
      // start from off, so a refused flip is visible as "stayed off"
      final s = await make(fake);
      fake.calls.clear(); // construction schedules once

      expect(await s.setReminderOn(true), isFalse);
      expect(s.reminderOn, isFalse);
      expect(fake.calls, isEmpty); // nothing scheduled behind the player's back
    });

    test('a throwing platform is a denial, not a crash', () async {
      // This is the macOS bug: initialize() threw out of requestPermission()
      // and took the whole toggle down with it.
      SharedPreferences.setMockInitialValues({'reminderOn': false});
      final fake = _FakeReminders(throwOnRequest: true);
      final s = await make(fake);

      expect(await s.setReminderOn(true), isFalse);
      expect(s.reminderOn, isFalse);
    });

    test('turning OFF never asks for permission', () async {
      SharedPreferences.setMockInitialValues({'reminderOn': true});
      final fake = _FakeReminders(throwOnRequest: true);
      final s = await make(fake);

      expect(await s.setReminderOn(false), isTrue);
      expect(s.reminderOn, isFalse);
      expect(fake.calls.last.on, isFalse);
    });
  });

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

  test('reminder time persists; the toggle defaults on at 9:00', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await make();
    expect(first.reminderOn, isTrue);
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
