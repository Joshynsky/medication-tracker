import 'package:flutter_riverpod/flutter_riverpod.dart';

// Holds which step we're on (0, 1, 2, or 3 for preview)
final currentStepProvider = StateProvider<int>((ref) => 0);

// Holds the selected schedule type
final scheduleTypeProvider = StateProvider<String>((ref) => 'once_daily');

// Photo paths (empty strings if not taken yet)
final photoOuterProvider = StateProvider<String>((ref) => '');
final photoInnerProvider = StateProvider<String>((ref) => '');
final photoPillsProvider = StateProvider<String>((ref) => '');

// Whether inner packaging photo was skipped
final hasInnerPackagingProvider = StateProvider<bool?>((ref) => null);

// Text fields
final medicationNameProvider = StateProvider<String>((ref) => '');
final dosageProvider = StateProvider<String>((ref) => '');
final pillCountProvider = StateProvider<String>((ref) => '');
final notesProvider = StateProvider<String>((ref) => '');

// Schedule details
final scheduleTimesProvider = StateProvider<List<Map<String, int>>>((ref) => [
  {'hour': 8, 'minute': 0},
]);
final intervalHoursProvider = StateProvider<int>((ref) => 6);
final customDaysProvider = StateProvider<Set<String>>((ref) => {'MON'});
final startDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Total number of steps (0, 1, 2 = form steps, 3 = preview)
const totalFormSteps = 3;