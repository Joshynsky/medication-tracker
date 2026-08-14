// Unit tests for MedicationRepository against a real in-memory drift/sqlite3
// database (no mocking of the database layer -- this is the actual query
// logic under test).
//
// saveMedication()/deleteMedication() also call through to AlarmService,
// which talks to flutter_local_notifications. See test/support/notifications_fake.dart
// for why that needs a fake platform registered under `flutter test`.
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/data/local/database.dart';
import 'package:medication_tracker/data/repositories/medication_repository.dart';

import '../support/notifications_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestNotifications();

  late AppDatabase db;
  late MedicationRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MedicationRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ensureDefaultUserAndPatient', () {
    test('creates a user and patient on first call', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();

      final users = await db.select(db.users).get();
      final patients = await db.select(db.patients).get();
      expect(users, hasLength(1));
      expect(patients, hasLength(1));
      expect(patients.single.id, patientId);
    });

    test('is idempotent: repeated calls return the same patient and do not duplicate rows', () async {
      final first = await repo.ensureDefaultUserAndPatient();
      final second = await repo.ensureDefaultUserAndPatient();
      final third = await repo.ensureDefaultUserAndPatient();

      expect(second, first);
      expect(third, first);

      final users = await db.select(db.users).get();
      final patients = await db.select(db.patients).get();
      expect(users, hasLength(1));
      expect(patients, hasLength(1));
    });
  });

  group('hasSeenOnboarding / markOnboardingSeen', () {
    test('is false before the user row exists', () async {
      expect(await repo.hasSeenOnboarding(), isFalse);
    });

    test('is false for a freshly-created user', () async {
      await repo.ensureDefaultUserAndPatient();
      expect(await repo.hasSeenOnboarding(), isFalse);
    });

    test('becomes true after markOnboardingSeen, and stays true', () async {
      await repo.ensureDefaultUserAndPatient();

      await repo.markOnboardingSeen();

      expect(await repo.hasSeenOnboarding(), isTrue);
      // Calling it again should be harmless and idempotent.
      await repo.markOnboardingSeen();
      expect(await repo.hasSeenOnboarding(), isTrue);
    });

    test('markOnboardingSeen is a no-op if no user row exists yet', () async {
      await repo.markOnboardingSeen();
      expect(await repo.hasSeenOnboarding(), isFalse);
      expect(await db.select(db.users).get(), isEmpty);
    });
  });

  group('saveMedication', () {
    test('inserts a medication that getMedications then returns', () async {
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

      final meds = await repo.getMedications(patientId);
      expect(meds, hasLength(1));
      expect(meds.single.id, medId);
      expect(meds.single.name, 'Amoxicillin');
      expect(meds.single.dosage, '500mg');
      expect(meds.single.scheduleType, 'once_daily');
    });

    test('once_daily generates one dose event per day across the 7-day window', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Metformin',
        dosage: '850mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      final history = await repo.getDoseHistory(medId);
      expect(history, hasLength(7));
      expect(history.every((d) => d.status == 'pending'), isTrue);
    });

    test('totalPills trims generated dose events to the pill count', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Short course',
        dosage: '250mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        totalPills: 3,
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      final history = await repo.getDoseHistory(medId);
      expect(history, hasLength(3));

      final meds = await repo.getMedications(patientId);
      expect(meds.single.totalPills, 3);
      expect(meds.single.pillsRemaining, 3);
    });

    test('multiple_times generates one dose event per configured time per day', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Ibuprofen',
        dosage: '400mg',
        scheduleType: 'multiple_times',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
          {'hour': 20, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      final history = await repo.getDoseHistory(medId);
      expect(history, hasLength(14)); // 2 times/day * 7 days
    });

    test('every_x_hours generates a dose event every N hours across the 7-day window', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Painkiller',
        dosage: '200mg',
        scheduleType: 'every_x_hours',
        startDateTime: DateTime(2020, 1, 1, 0, 0),
        times: [
          {'hour': 0, 'minute': 0},
        ],
        intervalHours: 6,
        customDays: {},
      );

      final history = await repo.getDoseHistory(medId);
      expect(history, hasLength(28)); // (7 days * 24h) / 6h
    });

    test('custom schedule only generates dose events on the configured weekdays', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      // 2026-01-05 is a Monday (self-verified below rather than assumed).
      final aMonday = DateTime(2026, 1, 5, 9, 0);
      expect(aMonday.weekday, DateTime.monday);

      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Weekly med',
        dosage: '1 tablet',
        scheduleType: 'custom',
        startDateTime: aMonday,
        times: [
          {'hour': 9, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {'MON'},
      );

      final history = await repo.getDoseHistory(medId);
      // Only one Monday falls within [startDateTime, startDateTime + 7 days).
      expect(history, hasLength(1));
      expect(history.single.scheduledTime, DateTime(2026, 1, 5, 9, 0));
    });
  });

  group('updateMedication', () {
    test('updates fields and regenerates dose events against the new schedule', () async {
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

      await repo.updateMedication(
        medicationId: medId,
        name: 'Amoxicillin',
        dosage: '500mg',
        scheduleType: 'every_x_hours',
        startDateTime: DateTime(2020, 2, 1, 16, 40),
        times: [
          {'hour': 16, 'minute': 40},
        ],
        intervalHours: 12,
        customDays: {},
      );

      final meds = await repo.getMedications(patientId);
      final updated = meds.singleWhere((m) => m.id == medId);
      expect(updated.scheduleType, 'every_x_hours');

      final history = await repo.getDoseHistory(medId);
      // Anchored at 16:40 (not midnight), so the 7-day cutoff (2020-02-08
      // 00:00) falls between the 13th dose (02-07 16:40) and what would've
      // been the 14th (02-08 04:40). With a 12h interval, doses alternate
      // 16:40/04:40 -- what matters is that the FIRST one is exactly the
      // configured 16:40, not midnight or some other startDateTime-derived
      // time.
      expect(history, hasLength(13));
      final sorted = [...history]
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      expect(sorted.first.scheduledTime, DateTime(2020, 2, 1, 16, 40));
    });

    test('preserves already-taken doses and their consumed pill count', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Ibuprofen',
        dosage: '200mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        totalPills: 21,
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      final firstDose = (await repo.getDoseHistory(medId)).first;
      await repo.confirmDose(firstDose.id, medId);

      await repo.updateMedication(
        medicationId: medId,
        name: 'Ibuprofen',
        dosage: '200mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        totalPills: 21,
        times: [
          {'hour': 9, 'minute': 0}, // changed dosage time
        ],
        intervalHours: 0,
        customDays: {},
      );

      final history = await repo.getDoseHistory(medId);
      final taken = history.where((d) => d.status == 'taken');
      final pending = history.where((d) => d.status == 'pending');
      expect(taken, hasLength(1), reason: 'the already-taken dose must survive the edit');
      expect(taken.single.id, firstDose.id);
      expect(
        pending,
        everyElement(predicate<DoseEvent>((d) => d.scheduledTime.hour == 9)),
        reason: 'newly regenerated pending doses should reflect the edited time',
      );

      final meds = await repo.getMedications(patientId);
      final updated = meds.singleWhere((m) => m.id == medId);
      expect(
        updated.pillsRemaining,
        20,
        reason: '21 total minus the 1 already taken, regardless of the edit',
      );
    });

    test('cancels and replaces alarms rather than leaving stale ones scheduled', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Painkiller',
        dosage: '200mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      // Should not throw -- exercises the cancel-then-reschedule path against
      // the fake notification plugin registered by setUpTestNotifications().
      await repo.updateMedication(
        medicationId: medId,
        name: 'Painkiller',
        dosage: '200mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 10, 0),
        times: [
          {'hour': 10, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );
    });
  });

  group('getMedications', () {
    test('excludes soft-deleted (inactive) medications', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final keepId = await repo.saveMedication(
        patientId: patientId,
        name: 'Keep me',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );
      final deleteId = await repo.saveMedication(
        patientId: patientId,
        name: 'Delete me',
        dosage: '20mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      await repo.deleteMedication(deleteId);

      final meds = await repo.getMedications(patientId);
      expect(meds.map((m) => m.id), [keepId]);
    });
  });

  group('getScheduleTimesForMedications', () {
    test('returns each medication\'s own ScheduleTimes rows, keyed by medicationId', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final onceDailyId = await repo.saveMedication(
        patientId: patientId,
        name: 'Once daily',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );
      final multipleTimesId = await repo.saveMedication(
        patientId: patientId,
        name: 'Three times a day',
        dosage: '20mg',
        scheduleType: 'multiple_times',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
          {'hour': 14, 'minute': 0},
          {'hour': 22, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      final byMedicationId = await repo.getScheduleTimesForMedications([
        onceDailyId,
        multipleTimesId,
      ]);

      expect(byMedicationId[onceDailyId], hasLength(1));
      expect(byMedicationId[onceDailyId]!.single.hour, 8);
      expect(byMedicationId[multipleTimesId], hasLength(3));
      expect(
        byMedicationId[multipleTimesId]!.map((s) => s.hour),
        containsAll([8, 14, 22]),
      );
    });

    test('returns an empty map for an empty medicationIds list', () async {
      final byMedicationId = await repo.getScheduleTimesForMedications([]);
      expect(byMedicationId, isEmpty);
    });
  });

  group('getTodaysDoses', () {
    test('returns only doses scheduled for the current calendar day', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Test med',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 9, 0);
      final yesterday = today.subtract(const Duration(days: 1));
      final nextWeek = today.add(const Duration(days: 7));

      await db.into(db.doseEvents).insert(
            DoseEventsCompanion.insert(
              medicationId: medId,
              scheduledTime: today,
              status: const Value('pending'),
            ),
          );
      await db.into(db.doseEvents).insert(
            DoseEventsCompanion.insert(
              medicationId: medId,
              scheduledTime: yesterday,
              status: const Value('pending'),
            ),
          );
      await db.into(db.doseEvents).insert(
            DoseEventsCompanion.insert(
              medicationId: medId,
              scheduledTime: nextWeek,
              status: const Value('pending'),
            ),
          );

      final todays = await repo.getTodaysDoses(patientId);
      expect(todays.map((d) => d.scheduledTime), [today]);
    });
  });

  group('confirmDose', () {
    test('marks the dose taken, stamps confirmedAt, and decrements pillsRemaining', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'Test med',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        totalPills: 10,
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );
      final dose = (await repo.getDoseHistory(medId)).first;

      await repo.confirmDose(dose.id, medId);

      final updatedDose =
          (await (db.select(db.doseEvents)..where((t) => t.id.equals(dose.id))).getSingle());
      expect(updatedDose.status, 'taken');
      expect(updatedDose.confirmedAt, isNotNull);

      final med = (await repo.getMedications(patientId)).single;
      expect(med.pillsRemaining, 9);
    });

    test('does not decrement pillsRemaining below zero', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'No pills left',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        totalPills: 0,
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );
      final dose = (await repo.getDoseHistory(medId)).first;

      await repo.confirmDose(dose.id, medId);

      final med = (await repo.getMedications(patientId)).single;
      expect(med.pillsRemaining, 0);
    });
  });

  group('snoozeDose', () {
    test('reschedules a reminder for the dose without changing its status', () async {
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
      final dose = (await repo.getDoseHistory(medId)).first;

      // Should not throw -- confirms snoozeDose actually does something now
      // (it used to be a no-op stub).
      await repo.snoozeDose(dose.id);

      final updated =
          await (db.select(db.doseEvents)..where((t) => t.id.equals(dose.id))).getSingle();
      expect(updated.status, 'pending');
    });

    test('is a no-op for a dose id that does not exist', () async {
      // Should not throw.
      await repo.snoozeDose(999999);
    });
  });

  group('deleteMedication', () {
    test('soft-deletes: row still exists but isActive becomes false', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'To delete',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      await repo.deleteMedication(medId);

      final row = await (db.select(db.medications)..where((t) => t.id.equals(medId))).getSingle();
      expect(row.isActive, isFalse);
    });
  });

  group('getDoseHistory', () {
    test('returns all dose events for a medication regardless of date or status', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      final medId = await repo.saveMedication(
        patientId: patientId,
        name: 'History test',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );
      final doses = await repo.getDoseHistory(medId);
      await repo.confirmDose(doses.first.id, medId);

      final history = await repo.getDoseHistory(medId);
      expect(history, hasLength(7));
      expect(history.where((d) => d.status == 'taken'), hasLength(1));
      expect(history.where((d) => d.status == 'pending'), hasLength(6));
    });
  });

  group('resetAllData', () {
    test('clears medications, dose events, patients, and users', () async {
      final patientId = await repo.ensureDefaultUserAndPatient();
      await repo.saveMedication(
        patientId: patientId,
        name: 'Anything',
        dosage: '10mg',
        scheduleType: 'once_daily',
        startDateTime: DateTime(2020, 1, 1, 8, 0),
        times: [
          {'hour': 8, 'minute': 0},
        ],
        intervalHours: 0,
        customDays: {},
      );

      await repo.resetAllData();

      expect(await db.select(db.users).get(), isEmpty);
      expect(await db.select(db.patients).get(), isEmpty);
      expect(await db.select(db.medications).get(), isEmpty);
      expect(await db.select(db.doseEvents).get(), isEmpty);
      expect(await db.select(db.scheduleTimes).get(), isEmpty);
    });
  });
}
