import 'package:flutter_riverpod/flutter_riverpod.dart';

class DayStatus {
  final DateTime date;
  final String status; // 'taken', 'missed', 'partial', 'no_doses'
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
  final String name;
  final String dosage;
  final String scheduleType;
  final int totalPills;
  final int pillsTaken;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  PastMedication({
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

  int get pillsRemaining => totalPills - pillsTaken;
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

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(_generateMockData());

  static HistoryState _generateMockData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate week days (Mon-Sun of current week)
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final weekDays = List.generate(7, (i) {
      final date = monday.add(Duration(days: i));
      if (date.isAfter(today)) {
        return DayStatus(date: date, status: 'no_doses', taken: 0, total: 0);
      }
      // Some random but realistic data
      if (i < today.weekday - 1) {
        if (i % 3 == 0) {
          return DayStatus(date: date, status: 'missed', taken: 1, total: 3);
        }
        return DayStatus(date: date, status: 'taken', taken: 3, total: 3);
      }
      // Today
      return DayStatus(date: date, status: 'partial', taken: 2, total: 3);
    });

    // Calculate adherence
    final daysWithDoses = weekDays.where((d) => d.total > 0).toList();
    final totalTaken = daysWithDoses.fold<int>(0, (sum, d) => sum + d.taken);
    final totalDoses = daysWithDoses.fold<int>(0, (sum, d) => sum + d.total);
    final weeklyAdherence = totalDoses > 0 ? (totalTaken / totalDoses) * 100 : 0.0;

    // Calculate streak
    int streak = 0;
    for (var i = today.weekday - 2; i >= 0; i--) {
      if (weekDays[i].status == 'taken') {
        streak++;
      } else {
        break;
      }
    }

    // Past medications
    final pastMedications = [
      PastMedication(
        name: 'Amoxicillin',
        dosage: '500mg',
        scheduleType: 'multiple_times',
        totalPills: 21,
        pillsTaken: 15,
        startDate: today.subtract(const Duration(days: 7)),
        endDate: today.add(const Duration(days: 3)),
        isActive: true,
      ),
      PastMedication(
        name: 'Metformin',
        dosage: '850mg',
        scheduleType: 'once_daily',
        totalPills: 30,
        pillsTaken: 8,
        startDate: today.subtract(const Duration(days: 10)),
        isActive: true,
      ),
      PastMedication(
        name: 'Ibuprofen',
        dosage: '400mg',
        scheduleType: 'every_x_hours',
        totalPills: 12,
        pillsTaken: 12,
        startDate: today.subtract(const Duration(days: 10)),
        endDate: today.subtract(const Duration(days: 5)),
        isActive: false,
      ),
      PastMedication(
        name: 'Paracetamol',
        dosage: '1g',
        scheduleType: 'once_daily',
        totalPills: 7,
        pillsTaken: 7,
        startDate: today.subtract(const Duration(days: 14)),
        endDate: today.subtract(const Duration(days: 8)),
        isActive: false,
      ),
    ];

    return HistoryState(
      weekDays: weekDays,
      pastMedications: pastMedications,
      weeklyAdherence: weeklyAdherence,
      currentStreak: streak,
    );
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
