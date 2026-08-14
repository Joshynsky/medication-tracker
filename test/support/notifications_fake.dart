import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

const _notificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

/// Call once per test file (top of `main()`) before exercising any code
/// that touches AlarmService/NotificationService or `package:timezone`.
///
/// flutter_local_notifications normally registers its platform-specific
/// implementation as a side effect of running on a real platform. Under
/// `flutter test` there's no platform, so nothing does that -- and some
/// calls (zonedSchedule, requestExactAlarmsPermission,
/// requestNotificationsPermission) specifically require a real
/// AndroidFlutterLocalNotificationsPlugin registered, not just any
/// FlutterLocalNotificationsPlatform subtype (they go through
/// `resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()`,
/// which checks the concrete type). The underlying platform channel gets a
/// permissive default handler so calls just succeed with no return value;
/// a test that needs to track specific calls, or simulate one being
/// rejected, can override the handler afterwards with its own
/// setMockMethodCallHandler.
void setUpTestNotifications() {
  tz_data.initializeTimeZones();
  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_notificationsChannel, (call) async => null);
}
