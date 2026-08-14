// Widget tests for NotificationPermissionDialog: the one-time
// "why we need notification permission" moment shown after the first
// medication save.
//
// requestNotificationsPermission()/requestExactAlarmsPermission() dispatch
// through resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>(),
// so (like zonedSchedule, see alarm_service_test.dart) they need a real
// AndroidFlutterLocalNotificationsPlugin registered, not the generic fake
// used elsewhere -- mocked at the raw platform-channel level instead.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/data/local/database.dart';
import 'package:medication_tracker/data/local/database_provider.dart';
import 'package:medication_tracker/data/repositories/medication_repository.dart';
import 'package:medication_tracker/shared/widgets/notification_permission_dialog.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');
const _permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

class _TriggerHarness extends ConsumerWidget {
  const _TriggerHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => NotificationPermissionDialog.showIfNeeded(context, ref),
          child: const Text('Trigger'),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();

  late AppDatabase db;
  late MedicationRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MedicationRepository(db);
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, null);
  });

  // "Enable Notifications" also requests battery-optimization exemption via
  // permission_handler, a separate plugin/channel from flutter_local_notifications.
  // Every test that taps that button needs this mocked or the request throws
  // MissingPluginException under flutter_test.
  void mockPermissionHandlerGrantsEverything() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionChannel, (call) async {
      if (call.method == 'requestPermissions') {
        final requested = (call.arguments as List).cast<int>();
        return {for (final code in requested) code: 1}; // 1 == granted
      }
      return null;
    });
  }

  Future<void> pumpHarness(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: _TriggerHarness()),
      ),
    );
  }

  testWidgets('shows the dialog on first trigger and marks onboarding seen after dismissing', (
    tester,
  ) async {
    await pumpHarness(tester);

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Stay on track with reminders'), findsOneWidget);
    expect(await repo.hasSeenOnboarding(), isFalse);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Stay on track with reminders'), findsNothing);
    expect(await repo.hasSeenOnboarding(), isTrue);
  });

  testWidgets('does not show the dialog again once onboarding has been seen', (tester) async {
    await repo.ensureDefaultUserAndPatient();
    await repo.markOnboardingSeen();

    await pumpHarness(tester);
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Stay on track with reminders'), findsNothing);
  });

  testWidgets(
    '"Enable Notifications" requests notification, exact-alarm, and battery-exemption permission',
    (tester) async {
      final calledMethods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
        calledMethods.add(call.method);
        return true;
      });
      mockPermissionHandlerGrantsEverything();

      await pumpHarness(tester);
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Notifications'));
      await tester.pumpAndSettle();

      expect(calledMethods, contains('requestNotificationsPermission'));
      expect(calledMethods, contains('requestExactAlarmsPermission'));
      expect(find.text('Stay on track with reminders'), findsNothing);
      expect(await repo.hasSeenOnboarding(), isTrue);
    },
  );
}
