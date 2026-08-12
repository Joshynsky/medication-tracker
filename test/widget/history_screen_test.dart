// Widget tests for HistoryScreen: confirms it renders without crashing in
// both the empty and populated states, and that the calendar and past
// medication cards are present.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/data/local/database.dart';
import 'package:medication_tracker/data/local/database_provider.dart';
import 'package:medication_tracker/data/repositories/medication_repository.dart';
import 'package:medication_tracker/features/history/screens/history_screen.dart';
import 'package:medication_tracker/features/history/widgets/adherence_calendar.dart';
import 'package:medication_tracker/features/history/widgets/past_medication_card.dart';

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

  Future<void> pumpHistory(WidgetTester tester) async {
    // See dashboard_screen_test.dart for why: the default test surface is
    // too short for this screen's scrollable content to fully build.
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the calendar without crashing when there are no medications', (
    tester,
  ) async {
    await pumpHistory(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AdherenceCalendar), findsOneWidget);
    // "This Week" legitimately appears twice: once as the stat card label,
    // once as AdherenceCalendar's own section header.
    expect(find.text('This Week'), findsNWidgets(2));
    expect(find.text('Streak'), findsOneWidget);
  });

  testWidgets('renders a past medication card once a medication exists', (tester) async {
    final repo = MedicationRepository(db);
    final patientId = await repo.ensureDefaultUserAndPatient();
    await repo.saveMedication(
      patientId: patientId,
      name: 'Vitamin D',
      dosage: '1000 IU',
      scheduleType: 'once_daily',
      startDateTime: DateTime(2020, 1, 1, 8, 0),
      times: [
        {'hour': 8, 'minute': 0},
      ],
      intervalHours: 0,
      customDays: {},
    );

    await pumpHistory(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(AdherenceCalendar), findsOneWidget);
    expect(find.byType(PastMedicationCard), findsWidgets);
    expect(find.text('Vitamin D'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
