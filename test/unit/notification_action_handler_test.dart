// Unit tests for NotificationActionHandler: dispatching a notification tap
// or action-button press to the same confirm/snooze logic the Dashboard's
// own buttons use, via a real ProviderContainer (mirroring main.dart).
//
// zonedSchedule (triggered by the snooze path) needs a real
// AndroidFlutterLocalNotificationsPlugin registered, same as
// alarm_service_test.dart -- see that file's header comment for why.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/data/local/database.dart';
import 'package:medication_tracker/data/local/database_provider.dart';
import 'package:medication_tracker/data/repositories/medication_repository.dart';
import 'package:medication_tracker/services/notification_action_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();

  late AppDatabase db;
  late MedicationRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MedicationRepository(db);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => null);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<({int doseId, int medicationId})> seedDose() async {
    final patientId = await repo.ensureDefaultUserAndPatient();
    final medId = await repo.saveMedication(
      patientId: patientId,
      name: 'Amoxicillin',
      dosage: '500mg',
      scheduleType: 'once_daily',
      startDateTime: DateTime(2020, 1, 1, 8, 0),
      times: [
        {'hour': 8, 'minute': 0},
      ],
      intervalHours: 0,
      customDays: {},
    );
    final doses = await repo.getDoseHistory(medId);
    return (doseId: doses.first.id, medicationId: medId);
  }

  Future<DoseEvent> doseRow(int doseId) =>
      (db.select(db.doseEvents)..where((t) => t.id.equals(doseId))).getSingle();

  test('take_dose confirms the dose via the real dashboard/provider chain', () async {
    final seeded = await seedDose();
    final response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: 'take_dose',
      payload: jsonEncode({'medicationId': seeded.medicationId, 'doseId': seeded.doseId}),
    );

    await NotificationActionHandler.handle(response, container);

    final updated = await doseRow(seeded.doseId);
    expect(updated.status, 'taken');
    expect(updated.confirmedAt, isNotNull);
  });

  test('snooze_dose reschedules a reminder without confirming the dose', () async {
    final seeded = await seedDose();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });

    final response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: 'snooze_dose',
      payload: jsonEncode({'medicationId': seeded.medicationId, 'doseId': seeded.doseId}),
    );

    await NotificationActionHandler.handle(response, container);

    expect(
      calls.where((c) => c.method == 'zonedSchedule'),
      isNotEmpty,
      reason: 'snoozing should schedule a new reminder',
    );
    final updated = await doseRow(seeded.doseId);
    expect(
      updated.status,
      'pending',
      reason: 'snoozing delays the reminder, it does not confirm the dose',
    );
  });

  test('a plain tap (no action button) does nothing, without throwing', () async {
    final seeded = await seedDose();
    final response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
      payload: jsonEncode({'medicationId': seeded.medicationId, 'doseId': seeded.doseId}),
    );

    await NotificationActionHandler.handle(response, container);

    final updated = await doseRow(seeded.doseId);
    expect(updated.status, 'pending');
  });

  test('ignores a response with no payload, without throwing', () async {
    const response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotification,
    );
    await NotificationActionHandler.handle(response, container);
  });

  test('ignores a response with malformed JSON payload, without throwing', () async {
    const response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: 'take_dose',
      payload: 'not valid json',
    );
    await NotificationActionHandler.handle(response, container);
  });

  test('ignores a response missing doseId/medicationId, without throwing', () async {
    const response = NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      actionId: 'take_dose',
      payload: '{}',
    );
    await NotificationActionHandler.handle(response, container);
  });
}
