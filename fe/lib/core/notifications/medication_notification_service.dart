import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Alarm-style local notifications for medication reminders - scheduled entirely on-device so
/// a dose is never missed even when offline. Android uses an exact, high-importance alarm
/// channel (bypasses Do Not Disturb-adjacent "urgent" behavior via max importance + full alert
/// sound); iOS uses the platform's default alert/sound presentation, since the elevated
/// interruption levels (`.timeSensitive`/`.critical`) require an Apple-granted entitlement this
/// app does not currently hold.
class MedicationNotificationService {
  MedicationNotificationService._();
  static final MedicationNotificationService instance =
      MedicationNotificationService._();

  static const _channelId = 'medication_reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init({
    required String channelName,
    required String channelDescription,
  }) async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // Falls back to whatever timezone package defaults to (UTC) - scheduling still
      // works, just without local-wall-clock DST correctness until this resolves.
    }

    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  // Each reminder is given a reserved block of [_slotsPerReminder] notification ids
  // (`base*_slotsPerReminder + doseIndex`), so a full reschedule can always clear every id a
  // reminder might have used previously without needing to remember what was scheduled last
  // time - no local persistence of notification ids required.
  static const _slotsPerReminder = 256;

  int _reminderBaseId(String reminderId) =>
      (reminderId.hashCode & 0x7FFFFFFF) % 1000000;

  /// Cancels every notification this reminder could have previously scheduled, then schedules
  /// one alarm per upcoming dose instant (capped to the reserved slot count). Call this after
  /// creating/editing a reminder and again whenever its upcoming schedule is refreshed from
  /// the backend.
  Future<void> rescheduleForReminder({
    required String reminderId,
    required String notificationBody,
    required List<DateTime> upcomingDoseInstantsUtc,
    required String channelName,
    required String channelDescription,
    required String notificationTitle,
  }) async {
    await init(channelName: channelName, channelDescription: channelDescription);
    final base = _reminderBaseId(reminderId) * _slotsPerReminder;
    for (var i = 0; i < _slotsPerReminder; i++) {
      await _plugin.cancel(base + i);
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    var index = 0;
    for (final instant in upcomingDoseInstantsUtc) {
      if (index >= _slotsPerReminder) break;
      final scheduledTz = tz.TZDateTime.from(instant, tz.local);
      if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) continue;
      await _plugin.zonedSchedule(
        base + index,
        notificationTitle,
        notificationBody,
        scheduledTz,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminderId,
      );
      index++;
    }
  }

  Future<void> cancelForReminder(
    String reminderId, {
    required String channelName,
    required String channelDescription,
  }) async {
    await init(channelName: channelName, channelDescription: channelDescription);
    final base = _reminderBaseId(reminderId) * _slotsPerReminder;
    for (var i = 0; i < _slotsPerReminder; i++) {
      await _plugin.cancel(base + i);
    }
  }
}
