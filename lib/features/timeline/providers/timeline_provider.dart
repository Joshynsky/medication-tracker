import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_provider.dart';
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

final timelineProvider = Provider<List<TimeSlot>>((ref) {
  final dashState = ref.watch(dashboardProvider);
  final todaysDoses = dashState.todaysDoses;
  final medications = dashState.medications;

  final Map<String, List<DoseEvent>> grouped = {};
  for (final dose in todaysDoses) {
    final timeKey = '${dose.scheduledTime.hour}:${dose.scheduledTime.minute}';
    grouped.putIfAbsent(timeKey, () => []);
    grouped[timeKey]!.add(dose);
  }

  final slots = <TimeSlot>[];
  final now = DateTime.now();

  for (final entry in grouped.entries) {
    if (entry.value.isEmpty) continue;
    final dose = entry.value.first;
    final meds = <Medication>[];
    for (final d in entry.value) {
      try {
        meds.add(medications.firstWhere((m) => m.id == d.medicationId));
      } catch (_) {}
    }

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

    slots.add(TimeSlot(
      time: dose.scheduledTime,
      doses: entry.value,
      medications: meds,
      status: status,
    ));
  }

  slots.sort((a, b) => a.time.compareTo(b.time));
  return slots;
});
