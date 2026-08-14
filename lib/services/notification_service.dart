import 'package:flutter/services.dart';
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

  /// [onNotificationResponse] is invoked when the user taps a notification
  /// or one of its action buttons. It's injected rather than hardcoded here
  /// so this service stays free of app-specific logic (parsing payloads,
  /// confirming/snoozing doses) -- see NotificationActionHandler, wired up
  /// from main().
  static Future<void> init({
    required void Function(NotificationResponse) onNotificationResponse,
  }) async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onNotificationResponse,
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
              'Take',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'snooze_dose',
              'Snooze 10 min',
              showsUserInterface: true,
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
              'Take',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: '{"medicationId": $medicationId, "notificationId": $id}',
    );
  }

  /// Requests the POST_NOTIFICATIONS runtime permission (Android 13+; a
  /// no-op returning true on older versions). Shows the in-app system
  /// dialog -- only call this from an explicit user action (onboarding, or
  /// More > Notification Settings), not automatically at startup.
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    try {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
