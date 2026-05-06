import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../data/local/database.dart';

class TimeSlot {
  final DateTime time;
  final List<DoseEvent> doses;
  final List<Medication> medications;
  final String status;

  TimeSlot({
    required this.time,
    required this.doses,
    required this.medications,
    required this.status,
  });

  String get timeLabel {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool get isTaken => doses.every((d) => d.status == 'taken');
  bool get isPending => doses.any((d) => d.status == 'pending');
  bool get isMissed => doses.any((d) => d.status == 'missed');
}

final timelineProvider = FutureProvider<List<TimeSlot>>((ref) async {
  final repo = ref.watch(medicationRepositoryProvider);
  final patientId = await repo.ensureDefaultUserAndPatient();
  final todaysDoses = await repo.getTodaysDoses(patientId);
  final medications = await repo.getMedications(patientId);

  final Map<String, List<DoseEvent>> grouped = {};
  for (final dose in todaysDoses) {
    final timeKey = '${dose.scheduledTime.hour}:${dose.scheduledTime.minute}';
    grouped.putIfAbsent(timeKey, () => []);
    grouped[timeKey]!.add(dose);
  }

  final slots = <TimeSlot>[];
  final now = DateTime.now();

  for (final entry in grouped.entries) {
    final dose = entry.value.first;
    final meds = entry.value.map((d) {
      return medications.firstWhere((m) => m.id == d.medicationId);
    }).toList();

    String status;
    if (entry.value.every((d) => d.status == 'taken')) {
      status = 'past';
    } else if (dose.scheduledTime.isBefore(now) &&
        dose.scheduledTime.add(const Duration(hours: 1)).isAfter(now)) {
      status = 'current';
    } else if (dose.scheduledTime.isAfter(now)) {
      status = 'upcoming';
    } else {
      status = 'past';
    }

    slots.add(
      TimeSlot(
        time: dose.scheduledTime,
        doses: entry.value,
        medications: meds,
        status: status,
      ),
    );
  }

  slots.sort((a, b) => a.time.compareTo(b.time));
  return slots;
});
