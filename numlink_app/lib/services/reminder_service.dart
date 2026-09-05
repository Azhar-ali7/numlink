import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One repeating local notification: "today's board is ready — keep the streak".
///
/// Local, not push: the daily reset is a wall-clock event the device can work
/// out on its own, so there is no server, no FCM, no token to manage. One
/// notification carries all three nudges (new daily, streak, come back and
/// play) because scheduled text is fixed at schedule time — three separate
/// alarms would just be three copies of the same reminder.
class ReminderService {
  static const _id = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Asked for on the first enable instead, so a player who never turns
        // reminders on is never prompted.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        // Same Darwin settings for macOS. Without this key the plugin throws
        // "macOS settings must be set" from initialize(), which took every
        // reminder call — including the settings toggle — down with it.
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// True once the OS has granted permission (or doesn't need to ask).
  Future<bool> requestPermission() async {
    await _init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
  }

  /// Re-arm (or clear) the daily reminder. Safe to call on every launch and on
  /// every settings change — it always cancels first, so there is only ever one.
  Future<void> schedule({
    required bool on,
    required int hour,
    required int minute,
  }) async {
    await _init();
    await _plugin.cancel(id: _id);
    if (!on) return;
    await _plugin.zonedSchedule(
      id: _id,
      title: 'Today\'s NUMLINK is ready',
      body: 'Solve it to keep your streak alive.',
      scheduledDate: _nextAt(hour, minute),
      matchDateTimeComponents: DateTimeComponents.time,
      // Inexact deliberately: exact alarms need SCHEDULE_EXACT_ALARM and a
      // second permission prompt on Android 14+, and a reminder is fine a few
      // minutes late.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'A nudge when the day\'s puzzle is ready',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// The next time [hour]:[minute] comes round, as an absolute instant.
  ///
  /// ponytail: `tz.local` is UTC because nothing sets the device zone (that
  /// needs the flutter_timezone dep). Converting a *local* DateTime lands the
  /// right absolute instant, and repeating on the time component keeps it
  /// there — so it drifts by an hour across a DST change and never otherwise.
  /// Add flutter_timezone and `tz.setLocalLocation` if that hour matters.
  static tz.TZDateTime _nextAt(int hour, int minute) {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    return tz.TZDateTime.from(when, tz.local);
  }
}
