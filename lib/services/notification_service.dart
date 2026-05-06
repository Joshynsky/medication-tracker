import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'dose_reminders',
    'Dose Reminders',
    description: 'Notifications for medication dose times',
    importance: Importance.high,
    showBadge: true,
    playSound: true,
    enableVibration: true,
  );

  static final AndroidNotificationChannel _snoozeChannel = const AndroidNotificationChannel(
    'dose_snooze',
    'Snoozed Reminders',
    description: 'Snoozed dose reminders',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create channels
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.createNotificationChannel(_snoozeChannel);
  }

  static Future<void> showDoseReminder({
    required int id,
    required String title,
    required String body,
    required int medicationId,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          ongoing: false,
          autoCancel: false,
          actions: [
            const AndroidNotificationAction(
              'take_dose',
              'I took them',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'snooze_dose',
              'Snooze 10 min',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: '{"medicationId": $medicationId, "notificationId": $id}',
    );
  }

  static Future<void> showSnoozeReminder({
    required int id,
    required String title,
    required String body,
    required int medicationId,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _snoozeChannel.id,
          _snoozeChannel.name,
          channelDescription: _snoozeChannel.description,
          importance: Importance.high,
          ongoing: false,
          autoCancel: false,
          actions: [
            const AndroidNotificationAction(
              'take_dose',
              'I took them',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: '{"medicationId": $medicationId, "notificationId": $id}',
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handled in app.dart via notification tap stream
  }
}
