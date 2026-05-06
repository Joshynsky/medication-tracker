import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../data/local/database.dart';

class DayStatus {
  final DateTime date;
  final String status;
  final int taken;
  final int total;

  DayStatus({
    required this.date,
    required this.status,
    required this.taken,
    required this.total,
  });
  bool get isAllTaken => status == 'taken';
  bool get isMissed => status == 'missed';
}

class PastMedication {
  final int id;
  final String name;
  final String dosage;
  final String scheduleType;
  final int totalPills;
  final int pillsTaken;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  PastMedication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduleType,
    required this.totalPills,
    required this.pillsTaken,
    required this.startDate,
    this.endDate,
    required this.isActive,
  });

  double get adherencePercent {
    if (totalPills == 0) return 0;
    return (pillsTaken / totalPills) * 100;
  }
}

class HistoryState {
  final List<DayStatus> weekDays;
  final List<PastMedication> pastMedications;
  final double weeklyAdherence;
  final int currentStreak;

  HistoryState({
    required this.weekDays,
    required this.pastMedications,
    required this.weeklyAdherence,
    required this.currentStreak,
  });
}

final historyProvider = FutureProvider<HistoryState>((ref) async {
  final repo = ref.watch(medicationRepositoryProvider);
  final patientId = await repo.ensureDefaultUserAndPatient();
  final medications = await repo.getMedications(patientId);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));

  // Build week day statuses from actual dose events
  final List<DayStatus> weekDays = [];
  int totalTakenInWeek = 0;
  int totalDosesInWeek = 0;

  for (int i = 0; i < 7; i++) {
    final date = monday.add(Duration(days: i));
    if (date.isAfter(today)) {
      weekDays.add(
        DayStatus(date: date, status: 'no_doses', taken: 0, total: 0),
      );
      continue;
    }

    int dayTaken = 0;
    int dayTotal = 0;

    for (final med in medications) {
      final doses = await repo.getDoseHistory(med.id);
      for (final dose in doses) {
        final doseDate = DateTime(
          dose.scheduledTime.year,
          dose.scheduledTime.month,
          dose.scheduledTime.day,
        );
        if (doseDate == date) {
          dayTotal++;
          if (dose.status == 'taken') dayTaken++;
        }
      }
    }

    totalTakenInWeek += dayTaken;
    totalDosesInWeek += dayTotal;

    String status;
    if (dayTotal == 0) {
      status = 'no_doses';
    } else if (dayTaken == dayTotal) {
      status = 'taken';
    } else if (dayTaken == 0) {
      status = 'missed';
    } else {
      status = 'partial';
    }

    weekDays.add(
      DayStatus(date: date, status: status, taken: dayTaken, total: dayTotal),
    );
  }

  final weeklyAdherence = totalDosesInWeek > 0
      ? (totalTakenInWeek / totalDosesInWeek) * 100
      : 0.0;

  // Calculate streak
  int streak = 0;
  for (var i = today.weekday - 2; i >= 0; i--) {
    if (weekDays[i].status == 'taken') {
      streak++;
    } else {
      break;
    }
  }

  // Build past medications from real data
  final pastMedications = <PastMedication>[];
  for (final med in medications) {
    final doses = await repo.getDoseHistory(med.id);
    final pillsTaken = doses.where((d) => d.status == 'taken').length;

    pastMedications.add(
      PastMedication(
        id: med.id,
        name: med.name,
        dosage: med.dosage,
        scheduleType: med.scheduleType,
        totalPills: med.totalPills,
        pillsTaken: pillsTaken,
        startDate: med.startDateTime,
        isActive: med.isActive,
      ),
    );
  }

  // Also get inactive medications
  final allMeds = await (_getAllMedications(repo, patientId));
  for (final med in allMeds.where((m) => !m.isActive)) {
    if (!pastMedications.any((p) => p.id == med.id)) {
      final doses = await repo.getDoseHistory(med.id);
      final pillsTaken = doses.where((d) => d.status == 'taken').length;
      pastMedications.add(
        PastMedication(
          id: med.id,
          name: med.name,
          dosage: med.dosage,
          scheduleType: med.scheduleType,
          totalPills: med.totalPills,
          pillsTaken: pillsTaken,
          startDate: med.startDateTime,
          isActive: false,
        ),
      );
    }
  }

  return HistoryState(
    weekDays: weekDays,
    pastMedications: pastMedications,
    weeklyAdherence: weeklyAdherence,
    currentStreak: streak,
  );
});

// Helper to get all medications including inactive
Future<List<Medication>> _getAllMedications(
  MedicationRepository repo,
  int patientId,
) async {
  // We need to query all meds not just active ones
  // For now, return just active ones since we don't have a direct method
  return await repo.getMedications(patientId);
}
