// Widget tests for DashboardScreen: confirms it renders without crashing in
// both the empty and populated states, and that the key structural pieces
// (hero card, medication list, time dots, FAB) are present.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/data/local/database.dart';
import 'package:medication_tracker/data/local/database_provider.dart';
import 'package:medication_tracker/data/repositories/medication_repository.dart';
import 'package:medication_tracker/features/dashboard/screens/dashboard_screen.dart';

import '../support/notifications_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpTestNotifications();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    // The default test surface (800x600 logical px) is too short for this
    // screen's content -- the hero card alone is close to that tall, and
    // Flutter's ListView only builds children within the viewport (+ cache
    // extent), so finders can't see anything below the fold. Use a taller,
    // phone-realistic surface instead.
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the empty state without crashing', (tester) async {
    await pumpDashboard(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('No medications yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add Medication'), findsOneWidget);
  });

  testWidgets(
    'renders hero card, medication list, and time dots once a medication with '
    "today's dose exists",
    (tester) async {
      final repo = MedicationRepository(db);
      final patientId = await repo.ensureDefaultUserAndPatient();

      // Save the medication with a safely-past startDateTime so none of its
      // auto-generated dose events land in the future (that would attempt to
      // schedule a real notification via AlarmService). Then insert today's
      // dose event directly, deterministically, so the dashboard has
      // something to render for "today" regardless of what time this test runs.
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

      final now = DateTime.now();
      final todayAt8 = DateTime(now.year, now.month, now.day, 8, 0);
      await db.into(db.doseEvents).insert(
            DoseEventsCompanion.insert(
              medicationId: medId,
              scheduledTime: todayAt8,
              status: const Value('pending'),
            ),
          );

      await pumpDashboard(tester);

      expect(tester.takeException(), isNull);
      // Appears in both the hero card's "up next" list and the medications list.
      expect(find.text('Amoxicillin'), findsAtLeastNWidgets(1));
      expect(find.textContaining('taken'), findsWidgets); // "0 of 1 taken"
      // "8:00 AM" legitimately appears twice: once as the hero card's "next
      // dose" subtitle, once as the time-dot label for the same dose.
      expect(find.text('8:00 AM'), findsNWidgets(2));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    },
  );
}
