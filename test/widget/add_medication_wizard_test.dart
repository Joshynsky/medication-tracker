// Widget tests for the Add Medication wizard: confirms each of the 4 steps
// (Identify, Schedule, Quantity, Preview) renders without crashing, that the
// step indicator reflects the current step, that each step shows its own
// fields, and that "Skip to preview" jumps straight to the preview.
//
// The Save button is intentionally not exercised here -- saving hits the
// real repository/database and is covered by the Stage 3 integration test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/features/add_medication/screens/add_medication_screen.dart';
import 'package:medication_tracker/features/add_medication/widgets/step_indicator.dart';

Future<void> pumpWizard(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(home: AddMedicationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Step 1 (Identify): step indicator shows 1 of 3 and identify fields are present', (
    tester,
  ) async {
    await pumpWizard(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(StepIndicator), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('What are you taking?'), findsOneWidget);
    expect(find.text('Medication name'), findsOneWidget);
    expect(find.text('Form'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
  });

  testWidgets('Step 2 (Schedule): step indicator shows 2 of 3 and schedule fields are present', (
    tester,
  ) async {
    await pumpWizard(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('When do you take it?'), findsOneWidget);
    expect(find.text('Schedule type'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
  });

  testWidgets('Step 3 (Quantity): step indicator shows 3 of 3 and quantity fields are present', (
    tester,
  ) async {
    await pumpWizard(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Next')); // -> step 2
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next')); // -> step 3
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('How much do you have?'), findsOneWidget);
    expect(find.text('Number of tablets'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('Step 4 (Preview): reached via "Preview" button, hides the step indicator, shows a summary', (
    tester,
  ) async {
    await pumpWizard(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Next')); // -> step 2
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next')); // -> step 3
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Preview')); // -> preview
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Preview has no step counter/indicator -- it's past totalFormSteps.
    expect(find.byType(StepIndicator), findsNothing);
    expect(find.textContaining('Step'), findsNothing);
    expect(find.text("Here's your plan"), findsOneWidget);
    expect(find.text('Unnamed medication'), findsOneWidget); // name left blank
    expect(find.textContaining('Once daily'), findsOneWidget); // default schedule
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
    // Save is built via FilledButton.icon(...), whose runtime type isn't
    // exactly FilledButton, so widgetWithIcon(FilledButton, ...) won't match
    // it -- check for the icon and label separately instead.
    expect(find.text('Save'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('"Skip to preview" jumps straight from step 1 to the preview', (tester) async {
    await pumpWizard(tester);

    expect(find.text("Here's your plan"), findsNothing);

    await tester.tap(find.text('Skip to preview'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("Here's your plan"), findsOneWidget);
    expect(find.byType(StepIndicator), findsNothing);
  });

  testWidgets('"Skip to preview" also works mid-wizard, from step 2', (tester) async {
    await pumpWizard(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Next')); // -> step 2
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);

    await tester.tap(find.text('Skip to preview'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("Here's your plan"), findsOneWidget);
  });

  testWidgets('"Edit" from the preview returns to step 3 (Quantity)', (tester) async {
    await pumpWizard(tester);

    await tester.tap(find.text('Skip to preview'));
    await tester.pumpAndSettle();
    expect(find.text("Here's your plan"), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('How much do you have?'), findsOneWidget);
  });
}
