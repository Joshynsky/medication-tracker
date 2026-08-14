import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import '../shared/schedule_window.dart';
import 'notification_service.dart';

/// A dose event id paired with the time it's scheduled for. Used to carry
/// the real doseId from MedicationRepository through to each notification's
/// payload, so a later tap on that notification knows which dose it's for.
class ScheduledDose {
  final int doseId;
  final DateTime time;

  const ScheduledDose({required this.doseId, required this.time});
}

class AlarmService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Schedules a notification, preferring exact timing and falling back to
  /// an inexact alarm if exact scheduling isn't available.
  ///
  /// Android only grants `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` when the
  /// user has explicitly enabled "Alarms & reminders" for the app (see
  /// AlarmService.requestExactAlarmPermission, surfaced from More >
  /// Notification Settings). There's no cheap way to check that from Dart
  /// before scheduling, and calling the plugin's permission-request method
  /// here would send the user to system Settings on every single dose
  /// scheduled -- so instead we just try exact first and fall back if the
  /// platform rejects it, rather than blocking the medication save (or the
  /// caller) on a permission the user may not have granted yet.
  static Future<void> zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {
      // Most likely the user hasn't granted the "Alarms & reminders"
      // permission. Still show the reminder, just without exact timing,
      // rather than losing it entirely.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Every notification id for a dose derives from its own doseId (globally
  /// unique, from the database) rather than a running counter tied to
  /// iteration order -- that makes each one individually addressable later
  /// (see [cancelDoseAlarms]), and avoids the old medicationId*1000-based
  /// scheme running out of room for medications with many doses.
  static int _windowOpenId(int doseId) => doseId * 4;
  static int _reminderId(int doseId) => doseId * 4 + 1;
  static int _missedId(int doseId) => doseId * 4 + 2;
  static int _snoozeId(int doseId) => doseId * 4 + 3;

  /// Schedules the three notifications for one dose:
  ///  1. Window opens (windowMinutes before the dose)
  ///  2. Coming up (reminderMinutes before the dose -- always inside the window)
  ///  3. Missed (windowMinutes after the dose, i.e. when the window closes) --
  ///     only meaningful if the dose is still pending by then; cancelled via
  ///     [cancelDoseAlarms] if the dose is confirmed taken first.
  static Future<void> scheduleDoseAlarms({
    required int doseId,
    required DateTime doseTime,
    required String medicationNames,
    required int medicationId,
    required int windowMinutes,
    required int reminderMinutes,
  }) async {
    final tzDoseTime = tz.TZDateTime.from(doseTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    final payload = '{"medicationId": $medicationId, "doseId": $doseId}';
    const takeAndSnooze = [
      AndroidNotificationAction('take_dose', 'Take', showsUserInterface: true, cancelNotification: true),
      AndroidNotificationAction('snooze_dose', 'Snooze', showsUserInterface: true, cancelNotification: true),
    ];
    const takeOnly = [
      AndroidNotificationAction('take_dose', 'Take', showsUserInterface: true, cancelNotification: true),
    ];

    final windowOpen = tzDoseTime.subtract(Duration(minutes: windowMinutes));
    if (windowOpen.isAfter(now)) {
      await zonedScheduleWithFallback(
        id: _windowOpenId(doseId),
        title: '💊 Time for your medication',
        body: medicationNames,
        scheduledDate: windowOpen,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Dose Reminders',
            channelDescription: 'Medication dose reminders',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            autoCancel: true,
            actions: takeAndSnooze,
          ),
        ),
        payload: payload,
      );
    }

    final comingUp = tzDoseTime.subtract(Duration(minutes: reminderMinutes));
    if (comingUp.isAfter(now)) {
      await zonedScheduleWithFallback(
        id: _reminderId(doseId),
        title: '⏰ Coming up',
        body: '$medicationNames — due in $reminderMinutes min',
        scheduledDate: comingUp,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Dose Reminders',
            channelDescription: 'Medication dose reminders',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            autoCancel: true,
            actions: takeAndSnooze,
          ),
        ),
        payload: payload,
      );
    }

    final missed = tzDoseTime.add(Duration(minutes: windowMinutes));
    if (missed.isAfter(now)) {
      await zonedScheduleWithFallback(
        id: _missedId(doseId),
        title: '⚠️ Missed dose',
        body: '$medicationNames — the window for this dose has closed',
        scheduledDate: missed,
        details: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Dose Reminders',
            channelDescription: 'Medication dose reminders',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            autoCancel: true,
            actions: takeOnly,
          ),
        ),
        payload: payload,
      );
    }
  }

  /// Schedules all (future) doses' notifications for a medication.
  ///
  /// [minutesOfDay] is only meaningful for `multiple_times` (see
  /// [scheduleCycleMinutes]) -- pass the sorted hour*60+minute list of every
  /// configured time for the medication; ignored otherwise.
  static Future<void> scheduleMedicationAlarms({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required List<ScheduledDose> doses,
    required String scheduleType,
    required int intervalHours,
    List<int> minutesOfDay = const [],
  }) async {
    final windowMins = scheduleWindowMinutes(scheduleType, intervalHours, minutesOfDay);
    final reminderMins = scheduleReminderMinutesBefore(windowMins);

    for (final dose in doses) {
      if (dose.time.isAfter(DateTime.now())) {
        await scheduleDoseAlarms(
          doseId: dose.doseId,
          doseTime: dose.time,
          medicationNames: '$medicationName $dosage',
          medicationId: medicationId,
          windowMinutes: windowMins,
          reminderMinutes: reminderMins,
        );
      }
    }
  }

  /// Reschedules a single dose's reminder to fire again after [delay]
  /// (10 minutes, from the "Snooze" notification action).
  static Future<void> scheduleSnoozeAlarm({
    required int doseId,
    required int medicationId,
    required String medicationName,
    required String dosage,
    Duration delay = const Duration(minutes: 10),
  }) async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(delay);
    await zonedScheduleWithFallback(
      id: _snoozeId(doseId),
      title: '⏰ Snoozed reminder',
      body: '$medicationName $dosage — time to take it',
      scheduledDate: snoozeTime,
      details: const NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_snooze',
          'Snoozed Reminders',
          channelDescription: 'Snoozed dose reminders',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          autoCancel: true,
          actions: [
            AndroidNotificationAction('take_dose', 'Take', showsUserInterface: true, cancelNotification: true),
          ],
        ),
      ),
      payload: '{"medicationId": $medicationId, "doseId": $doseId}',
    );
  }

  /// Cancels every notification that could still be pending for one dose
  /// (window-open, coming-up, missed, and any active snooze). Call when a
  /// dose is confirmed taken (so a stale "missed" notification can't still
  /// show up later) or when its medication is deleted/edited.
  static Future<void> cancelDoseAlarms(int doseId) async {
    await NotificationService.cancelNotification(_windowOpenId(doseId));
    await NotificationService.cancelNotification(_reminderId(doseId));
    await NotificationService.cancelNotification(_missedId(doseId));
    await NotificationService.cancelNotification(_snoozeId(doseId));
  }

  /// Requests the "Alarms & reminders" permission Android 12+ requires for
  /// exact alarm scheduling. This always sends the user to system Settings
  /// (Android has no in-app dialog for this specific permission) -- only
  /// call it from an explicit user action (onboarding, or More > Notification
  /// Settings), never from the scheduling path itself.
  static Future<bool> requestExactAlarmPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    try {
      return await androidPlugin.requestExactAlarmsPermission() ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Requests exemption from Android's battery optimization (Doze), via the
  /// system's "Ignore battery optimizations" dialog. Without this, Android
  /// (and especially MIUI/other OEM battery managers on top of it) can kill
  /// the app's process before a scheduled alarm's broadcast reaches the code
  /// that posts the notification -- the alarm still fires at the OS level,
  /// but nothing visible happens. Only call from an explicit user action
  /// (onboarding, or More > Notification Settings), same as
  /// requestExactAlarmPermission.
  ///
  /// This does not cover OEM-specific extras like MIUI's separate
  /// "Autostart" toggle -- there's no standard Android API for those; the
  /// user has to enable them manually in system Settings.
  static Future<bool> requestBatteryOptimizationExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }
}
