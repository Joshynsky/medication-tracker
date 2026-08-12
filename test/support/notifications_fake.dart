import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:timezone/data/latest.dart' as tz_data;

/// flutter_local_notifications normally registers its platform-specific
/// implementation as a side effect of running on a real platform. Under
/// `flutter test` there's no platform, so nothing ever sets
/// [FlutterLocalNotificationsPlatform.instance], and any call into the
/// plugin throws a LateInitializationError. Repository code (via
/// AlarmService/NotificationService) calls into the plugin as a side effect
/// of saving/deleting medications, so any test exercising that path needs a
/// platform registered up front.
class NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> show(
    int id,
    String? title,
    String? body, {
    String? payload,
  }) async {}
}

/// Call once per test file (top of `main()`) before exercising any code
/// that touches AlarmService/NotificationService or `package:timezone`.
void setUpTestNotifications() {
  tz_data.initializeTimeZones();
  FlutterLocalNotificationsPlatform.instance = NoopNotificationsPlatform();
}
