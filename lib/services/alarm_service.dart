import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Schedule both window-open and closing-soon notifications for a dose
  static Future<void> scheduleDoseAlarms({
    required int baseId,
    required DateTime doseTime,
    required String medicationNames,
    required int medicationId,
    required int windowMinutes,
  }) async {
    final tzDoseTime = tz.TZDateTime.from(doseTime, tz.local);
    
    // Notification 1: Window opens (windowMinutes before dose)
    final windowOpen = tzDoseTime.subtract(Duration(minutes: windowMinutes));
    if (windowOpen.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.zonedSchedule(
        baseId,
        '💊 Time for your medication',
        medicationNames,
        windowOpen,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Dose Reminders',
            channelDescription: 'Medication dose reminders',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            autoCancel: true,
            actions: [
              AndroidNotificationAction('take_dose', 'I took them', showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction('snooze_dose', 'Snooze', showsUserInterface: false, cancelNotification: true),
            ],
          ),
        ),
        payload: '{"medicationId": $medicationId, "notificationId": ${baseId}}',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Notification 2: Window closing soon (15 min before close = doseTime + windowMinutes - 15)
    final closingSoon = tzDoseTime.add(Duration(minutes: windowMinutes - 15));
    if (closingSoon.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.zonedSchedule(
        baseId + 1,
        '⏰ Window closing soon!',
        '$medicationNames — take now before it\'s too late',
        closingSoon,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dose_reminders',
            'Dose Reminders',
            channelDescription: 'Medication dose reminders',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
            autoCancel: true,
            actions: [
              AndroidNotificationAction('take_dose', 'I took them', showsUserInterface: true, cancelNotification: true),
            ],
          ),
        ),
        payload: '{"medicationId": $medicationId, "notificationId": ${baseId + 1}}',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Schedule both notifications for all doses of a medication
  static Future<void> scheduleMedicationAlarms({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required List<DateTime> doseTimes,
    required String scheduleType,
    required int intervalHours,
  }) async {
    final windowMins = _getWindowMinutes(scheduleType, intervalHours);
    int alarmId = medicationId * 1000;

    for (final time in doseTimes) {
      if (time.isAfter(DateTime.now())) {
        await scheduleDoseAlarms(
          baseId: alarmId,
          doseTime: time,
          medicationNames: '$medicationName $dosage',
          medicationId: medicationId,
          windowMinutes: windowMins,
        );
        alarmId += 2; // Skip 2 IDs (one per notification)
      }
    }
  }

  static Future<void> cancelMedicationAlarms(int medicationId) async {
    int alarmId = medicationId * 1000;
    for (int i = 0; i < 60; i++) {
      await NotificationService.cancelNotification(alarmId + i);
    }
  }

  static int _getWindowMinutes(String scheduleType, int intervalHours) {
    switch (scheduleType) {
      case 'every_x_hours': return (intervalHours * 60) ~/ 6;
      case 'once_daily': return 120;
      case 'multiple_times': return 60;
      default: return 60;
    }
  }
}
