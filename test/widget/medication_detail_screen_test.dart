// Widget tests for MedicationDetailScreen. The screen takes its Medication
// directly as a constructor argument rather than loading it via a provider,
// so no database setup is needed for basic rendering.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/features/medication_detail/screens/detail_screen.dart';

import '../unit/fixtures.dart';

void main() {
  testWidgets('renders without crashing and shows key medication info', (tester) async {
    final med = buildMedication(
      id: 1,
      name: 'Lisinopril',
      dosage: '10mg',
      form: 'pills',
      scheduleType: 'once_daily',
      startDateTime: DateTime(2026, 1, 1, 8, 0),
      totalPills: 30,
      pillsRemaining: 20,
      quantityUnit: 'tablets',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MedicationDetailScreen(medication: med)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // AppBar title + the info card both show the name.
    expect(find.text('Lisinopril'), findsAtLeastNWidgets(1));
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Once daily'), findsOneWidget);
    expect(find.text('20 tablets remaining'), findsOneWidget);
    expect(find.text('Delete Medication'), findsOneWidget);
  });

  testWidgets('tapping Delete Medication shows a confirmation dialog', (tester) async {
    final med = buildMedication(
      id: 2,
      name: 'Metformin',
      dosage: '850mg',
      scheduleType: 'once_daily',
      startDateTime: DateTime(2026, 1, 1, 8, 0),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MedicationDetailScreen(medication: med)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete Medication'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Are you sure you want to delete Metformin?'),
      findsOneWidget,
    );
  });
}
