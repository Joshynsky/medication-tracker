import 'package:flutter_riverpod/flutter_riverpod.dart';

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
