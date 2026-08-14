// Unit tests for AlarmService's exact-alarm-with-fallback scheduling.
//
// zonedSchedule() dispatches through
// resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!
// (note the force-unwrap), so unlike cancel()/cancelAll()/show() this
// specifically requires a real AndroidFlutterLocalNotificationsPlugin
// registered as FlutterLocalNotificationsPlatform.instance -- the generic
// NoopNotificationsPlatform fake used elsewhere isn't enough here. We mock
// the raw platform channel instead, one level below the plugin API.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/services/alarm_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('schedules exact when the platform accepts it, with no fallback call', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });

    await AlarmService.zonedScheduleWithFallback(
      id: 1,
      title: 'Test',
      body: 'Body',
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5)),
      details: const NotificationDetails(
        android: AndroidNotificationDetails('dose_reminders', 'Dose Reminders'),
      ),
      payload: '{}',
    );

    final zonedScheduleCalls = calls.where((c) => c.method == 'zonedSchedule');
    expect(
      zonedScheduleCalls,
      hasLength(1),
      reason: 'exact scheduling succeeded, so no fallback attempt should occur',
    );
  });

  test(
    'falls back to inexact scheduling when exact scheduling is rejected '
    '(e.g. exact-alarm permission not granted)',
    () async {
      final calls = <MethodCall>[];
      var callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        if (call.method == 'zonedSchedule') {
          callCount++;
          if (callCount == 1) {
            // Simulate the platform rejecting the first (exact) attempt.
            throw PlatformException(
              code: 'exact_alarms_not_permitted',
              message: 'ExactAlarmPermissionException',
            );
          }
        }
        return null;
      });

      // Should not throw -- the fallback call should succeed even though
      // the first (exact) attempt was rejected.
      await AlarmService.zonedScheduleWithFallback(
        id: 2,
        title: 'Test',
        body: 'Body',
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5)),
        details: const NotificationDetails(
          android: AndroidNotificationDetails('dose_reminders', 'Dose Reminders'),
        ),
        payload: '{}',
      );

      final zonedScheduleCalls = calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(
        zonedScheduleCalls,
        hasLength(2),
        reason: 'the rejected exact attempt should be followed by exactly one inexact fallback attempt',
      );
    },
  );

  group('scheduleDoseAlarms', () {
    test('schedules all three notifications when the dose is far enough in the future', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        return null;
      });

      // 2 hours out: window opens (30 min before), coming-up (10 min
      // before), and missed (30 min after) are all still in the future.
      final doseTime = DateTime.now().add(const Duration(hours: 2));
      await AlarmService.scheduleDoseAlarms(
        doseId: 42,
        doseTime: doseTime,
        medicationNames: 'Amoxicillin 500mg',
        medicationId: 1,
        windowMinutes: 30,
        reminderMinutes: 10,
      );

      final zonedScheduleCalls = calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(zonedScheduleCalls, hasLength(3));
      final ids = zonedScheduleCalls.map((c) => (c.arguments as Map)['id']).toSet();
      expect(
        ids,
        {42 * 4, 42 * 4 + 1, 42 * 4 + 2},
        reason: 'ids should derive from doseId (window-open, coming-up, missed)',
      );
    });

    test('skips notifications whose trigger time has already passed', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        return null;
      });

      // Only 5 minutes out, with a 30-minute window: window-open (-30min)
      // and coming-up (-10min) trigger times are already in the past, only
      // the missed notification (+30min from dose time) is still upcoming.
      final doseTime = DateTime.now().add(const Duration(minutes: 5));
      await AlarmService.scheduleDoseAlarms(
        doseId: 7,
        doseTime: doseTime,
        medicationNames: 'Ibuprofen 200mg',
        medicationId: 2,
        windowMinutes: 30,
        reminderMinutes: 10,
      );

      final zonedScheduleCalls = calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(zonedScheduleCalls, hasLength(1));
      expect((zonedScheduleCalls.single.arguments as Map)['id'], 7 * 4 + 2);
    });
  });

  test('cancelDoseAlarms cancels all four possible notification ids for a dose', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });

    await AlarmService.cancelDoseAlarms(9);

    final cancelledIds = calls
        .where((c) => c.method == 'cancel')
        .map((c) => (c.arguments as Map)['id'])
        .toList();
    expect(cancelledIds, [9 * 4, 9 * 4 + 1, 9 * 4 + 2, 9 * 4 + 3]);
  });
}
