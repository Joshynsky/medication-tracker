import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/database.dart';

final currentStepProvider = StateProvider<int>((ref) => 0);
final scheduleTypeProvider = StateProvider<String>((ref) => 'once_daily');

final photoOuterProvider = StateProvider<String>((ref) => '');
final photoInnerProvider = StateProvider<String>((ref) => '');
final photoPillsProvider = StateProvider<String>((ref) => '');

final hasInnerPackagingProvider = StateProvider<bool?>((ref) => null);

final medicationNameProvider = StateProvider<String>((ref) => '');
final dosageProvider = StateProvider<String>((ref) => '');
final pillCountProvider = StateProvider<String>((ref) => '');
final notesProvider = StateProvider<String>((ref) => '');

// New fields
final formProvider = StateProvider<String>((ref) => 'pills');
final strengthValueProvider = StateProvider<String>((ref) => '');
final strengthUnitProvider = StateProvider<String>((ref) => 'mg');
final amountPerDoseProvider = StateProvider<String>((ref) => '1');
final amountUnitProvider = StateProvider<String>((ref) => 'tablet');
final quantityUnitProvider = StateProvider<String>((ref) => 'tablets');

final scheduleTimesProvider = StateProvider<List<Map<String, int>>>((ref) => [
  {'hour': 8, 'minute': 0},
]);
final intervalHoursProvider = StateProvider<int>((ref) => 6);
final customDaysProvider = StateProvider<Set<String>>((ref) => {'MON'});
final startDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

const totalFormSteps = 3;

/// These providers are app-lifetime (not scoped to the wizard screen), so
/// without an explicit reset a second "Add Medication" pass -- whether
/// reached after a successful save or after backing out without saving --
/// would silently reopen showing the previous medication's data. Call this
/// right before pushing AddMedicationScreen, so the wizard already starts
/// clean on its very first build.
void resetAddMedicationState(WidgetRef ref) {
  ref.invalidate(currentStepProvider);
  ref.invalidate(scheduleTypeProvider);
  ref.invalidate(photoOuterProvider);
  ref.invalidate(photoInnerProvider);
  ref.invalidate(photoPillsProvider);
  ref.invalidate(hasInnerPackagingProvider);
  ref.invalidate(medicationNameProvider);
  ref.invalidate(dosageProvider);
  ref.invalidate(pillCountProvider);
  ref.invalidate(notesProvider);
  ref.invalidate(formProvider);
  ref.invalidate(strengthValueProvider);
  ref.invalidate(strengthUnitProvider);
  ref.invalidate(amountPerDoseProvider);
  ref.invalidate(amountUnitProvider);
  ref.invalidate(quantityUnitProvider);
  ref.invalidate(scheduleTimesProvider);
  ref.invalidate(intervalHoursProvider);
  ref.invalidate(customDaysProvider);
  ref.invalidate(startDateProvider);
}

String _formatNum(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Populates the wizard's fields from an existing medication, so opening
/// "Edit" shows its current data instead of a blank/reset form. Call after
/// resetAddMedicationState, right before pushing AddMedicationScreen in edit
/// mode.
///
/// startDateProvider is deliberately set to today, not the medication's
/// original startDateTime: editing regenerates the schedule's future dose
/// events from whatever startDateProvider holds at save time (see
/// MedicationRepository.updateMedication), and the original start date is
/// often already in the past -- anchoring on it again could generate a
/// schedule window that's already over.
void populateAddMedicationStateForEdit(
  WidgetRef ref,
  Medication med,
  List<ScheduleTime> scheduleTimes,
) {
  ref.read(medicationNameProvider.notifier).state = med.name;
  ref.read(dosageProvider.notifier).state = med.dosage;
  ref.read(pillCountProvider.notifier).state =
      med.totalPills > 0 ? med.totalPills.toString() : '';
  ref.read(notesProvider.notifier).state = med.notes ?? '';
  ref.read(formProvider.notifier).state = med.form;
  ref.read(strengthValueProvider.notifier).state =
      med.strengthValue != null ? _formatNum(med.strengthValue!) : '';
  ref.read(strengthUnitProvider.notifier).state = med.strengthUnit ?? 'mg';
  ref.read(amountPerDoseProvider.notifier).state = _formatNum(med.amountPerDose);
  ref.read(amountUnitProvider.notifier).state = med.amountUnit;
  ref.read(quantityUnitProvider.notifier).state = med.quantityUnit;
  ref.read(scheduleTypeProvider.notifier).state = med.scheduleType;
  ref.read(startDateProvider.notifier).state = DateTime.now();

  final sortedTimes = [...scheduleTimes]
    ..sort((a, b) => (a.hour ?? 0) != (b.hour ?? 0)
        ? (a.hour ?? 0).compareTo(b.hour ?? 0)
        : (a.minute ?? 0).compareTo(b.minute ?? 0));
  if (sortedTimes.isNotEmpty) {
    ref.read(scheduleTimesProvider.notifier).state = sortedTimes
        .map((t) => {'hour': t.hour ?? 8, 'minute': t.minute ?? 0})
        .toList();
    final intervalRow = sortedTimes.firstWhere(
      (t) => t.intervalHours != null,
      orElse: () => sortedTimes.first,
    );
    if (intervalRow.intervalHours != null) {
      ref.read(intervalHoursProvider.notifier).state = intervalRow.intervalHours!;
    }
    final daysRow = sortedTimes.firstWhere(
      (t) => t.daysOfWeek != null,
      orElse: () => sortedTimes.first,
    );
    if (daysRow.daysOfWeek != null && daysRow.daysOfWeek!.isNotEmpty) {
      ref.read(customDaysProvider.notifier).state =
          daysRow.daysOfWeek!.split(',').toSet();
    }
  }
}
