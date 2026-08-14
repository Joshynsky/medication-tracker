// End-to-end integration test for MediTrack's core flow:
//   add a medication through the wizard -> see it on the dashboard ->
//   confirm a dose -> see it reflected in history.
//
// This exercises the REAL widget tree (MeditrackApp), not a screen in
// isolation, and (aside from swapping in an in-memory database so the test
// doesn't pollute/depend on real on-device app data) does not mock anything
// -- it drives the actual UI the way a user would.
//
// Must run on a real device or emulator (see the Stage 3 report for why
// `flutter test` can't run this file).
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medication_tracker/app.dart';
import 'package:medication_tracker/data/local/database.dart';
import 'package:medication_tracker/data/local/database_provider.dart';
import 'package:medication_tracker/features/history/widgets/past_medication_card.dart';
import 'package:medication_tracker/features/medication_detail/screens/detail_screen.dart';
import 'package:medication_tracker/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'add medication -> appears on dashboard -> confirm dose -> reflected in history',
    (tester) async {
      tz_data.initializeTimeZones();
      await NotificationService.init(onNotificationResponse: (_) {});

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: MeditrackApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starting point: fresh install, no medications yet.
      expect(find.text('No medications yet'), findsOneWidget);

      // --- Add a medication through the wizard ---

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Step 1: Identify.
      expect(find.text('Step 1 of 3'), findsOneWidget);
      await tester.enterText(
        find.ancestor(
          of: find.text('e.g., Amoxicillin'),
          matching: find.byType(TextField),
        ),
        'Amoxicillin',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.ancestor(
          of: find.text('e.g., 500'),
          matching: find.byType(TextField),
        ),
        '500',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip photos'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Step 2: Schedule. Leave the defaults (once daily, 8:00 AM, starting
      // today) -- realistic, and keeps this test independent of a fragile
      // Material time-picker automation. The dose time is adjusted directly
      // in the database further down so "confirm a dose" is deterministic
      // regardless of what time of day this test happens to run.
      expect(find.text('Step 2 of 3'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Step 3: Quantity.
      expect(find.text('Step 3 of 3'), findsOneWidget);
      await tester.enterText(
        find.ancestor(
          of: find.textContaining('e.g., 21'),
          matching: find.byType(TextField),
        ),
        '21',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Preview'));
      await tester.pumpAndSettle();

      // Step 4: Preview -- sanity-check what we're about to save.
      expect(find.text("Here's your plan"), findsOneWidget);
      expect(find.text('Amoxicillin'), findsOneWidget);
      expect(find.textContaining('500mg'), findsOneWidget);
      expect(find.textContaining('Once daily'), findsOneWidget);
      expect(find.text('21 tablets'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // This is the first (and, for this test, only) medication ever saved,
      // so NotificationPermissionDialog.showIfNeeded shows the onboarding
      // dialog here -- it's barrierDismissible: false and _saveMedication
      // awaits it before popping back to the Dashboard, so nothing below
      // this point works until it's dismissed. Tap "Not now" rather than
      // "Enable Notifications": that button calls into the real native
      // Android permission dialog, which lives outside the Flutter engine
      // entirely -- integration_test has no way to find or dismiss it, so
      // tapping it would just hang. Real permission-dialog behavior isn't
      // testable here regardless of which button we pick.
      expect(find.text('Stay on track with reminders'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      // --- Confirm it appears on the Dashboard ---

      expect(find.text('No medications yet'), findsNothing);
      expect(find.text('Amoxicillin'), findsAtLeastNWidgets(1));

      // The "Amoxicillin saved!" SnackBar is still on screen at this point
      // and can intercept taps on whatever's underneath it. Its Overlay
      // entry stays hit-testable (fading out) for a bit even after the
      // SnackBar widget itself is gone from the tree, so neither a fixed
      // wait nor polling find.byType(SnackBar) is reliable here. Use
      // ScaffoldMessenger's own API to dismiss it outright instead of
      // guessing at timing.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // once_daily generates 7 days of dose events; only today's is
      // relevant here. Move it to a couple of minutes ago so it's
      // deterministically inside the dashboard's confirm window, regardless
      // of what wall-clock time this test happens to run at.
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final todaysDoseRows = await (db.select(
        db.doseEvents,
      )..where((t) => t.scheduledTime.isBetweenValues(todayStart, todayEnd))).get();
      expect(
        todaysDoseRows,
        hasLength(1),
        reason: 'once_daily should generate exactly one dose event for today',
      );
      await (db.update(
        db.doseEvents,
      )..where((t) => t.id.equals(todaysDoseRows.single.id))).write(
        DoseEventsCompanion(
          scheduledTime: Value(now.subtract(const Duration(minutes: 2))),
        ),
      );

      // Trigger a dashboard refresh the way the app itself does: navigate
      // into the medication's detail screen and back.
      //
      // ensureVisible (not scrollUntilVisible) deliberately: scrollUntilVisible
      // stops as soon as the target is merely hit-testable, which can leave it
      // sitting right at the viewport edge, close enough to the FAB/bottom nav
      // area to intermittently fail the tap below. ensureVisible computes the
      // scroll offset needed to fully reveal the widget instead.
      await tester.ensureVisible(find.text('Amoxicillin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amoxicillin').last);
      await tester.pumpAndSettle();
      expect(find.byType(MedicationDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // --- Confirm a dose ---

      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Take'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(FilledButton, 'Take'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Take'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Take'), findsNothing);

      // --- Confirm it's reflected in History ---

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.byType(PastMedicationCard), findsWidgets);
      expect(find.text('Amoxicillin'), findsOneWidget);
      expect(
        find.text('1/21'),
        findsOneWidget,
        reason: 'exactly one of the 21 pills has been confirmed taken',
      );
      expect(find.textContaining('adherence'), findsWidgets);
    },
  );
}
