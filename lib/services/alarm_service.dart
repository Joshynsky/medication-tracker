import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_service.dart';

class AlarmService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> scheduleDoseAlarm({
    required int id,
    required DateTime scheduledTime,
    required String medicationNames,
    required int medicationId,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      '💊 Time for your medication',
      medicationNames,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_reminders',
          'Dose Reminders',
          channelDescription: 'Medication dose reminders',
          importance: Importance.max,
          priority: Priority.high,
          ongoing: false,
          autoCancel: false,
          actions: [
            AndroidNotificationAction(
              'take_dose',
              'I took them',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'snooze_dose',
              'Snooze 10 min',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: '{"medicationId": $medicationId, "notificationId": $id}',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> scheduleMedicationAlarms({
    required int medicationId,
    required String medicationName,
    required String dosage,
    required List<DateTime> doseTimes,
  }) async {
    int alarmId = medicationId * 1000;

    for (final time in doseTimes) {
      if (time.isAfter(DateTime.now())) {
        await scheduleDoseAlarm(
          id: alarmId,
          scheduledTime: time,
          medicationNames: '$medicationName $dosage',
          medicationId: medicationId,
        );
        alarmId++;
      }
    }
  }

  static Future<void> cancelMedicationAlarms(int medicationId) async {
    int alarmId = medicationId * 1000;
    for (int i = 0; i < 30; i++) {
      await NotificationService.cancelNotification(alarmId + i);
    }
  }
}
