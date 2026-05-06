import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple mock medication model
class MockMedication {
  final int id;
  final String name;
  final String dosage;
  final String scheduleType;
  final int totalPills;
  final int pillsRemaining;
  final bool isActive;

  MockMedication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduleType,
    required this.totalPills,
    required this.pillsRemaining,
    required this.isActive,
  });
}

// Mock dose event
class MockDoseEvent {
  final int id;
  final int medicationId;
  final DateTime scheduledTime;
  String status; // 'pending', 'taken', 'missed'
  int snoozeCount = 0;

  MockDoseEvent({
    required this.id,
    required this.medicationId,
    required this.scheduledTime,
    required this.status,
  });
}

class MockMedicationRepository {
  int _nextMedId = 1;
  int _nextDoseId = 1;

  final List<MockMedication> _medications = [];
  final List<MockDoseEvent> _doseEvents = [];

  MockMedicationRepository() {
    _setupMockData();
  }

  void _setupMockData() {
    final now = DateTime.now();
    final today8am = DateTime(now.year, now.month, now.day, 8, 0);
    final today2pm = DateTime(now.year, now.month, now.day, 14, 0);
    final today10pm = DateTime(now.year, now.month, now.day, 22, 0);

    // Medication 1: Amoxicillin
    final med1 = MockMedication(
      id: _nextMedId++,
      name: 'Amoxicillin',
      dosage: '500mg',
      scheduleType: 'multiple_times',
      totalPills: 21,
      pillsRemaining: 15,
      isActive: true,
    );
    _medications.add(med1);

    _doseEvents.addAll([
      MockDoseEvent(id: _nextDoseId++, medicationId: med1.id, scheduledTime: today8am, status: 'taken'),
      MockDoseEvent(id: _nextDoseId++, medicationId: med1.id, scheduledTime: today2pm, status: 'pending'),
      MockDoseEvent(id: _nextDoseId++, medicationId: med1.id, scheduledTime: today10pm, status: 'pending'),
    ]);

    // Medication 2: Metformin
    final med2 = MockMedication(
      id: _nextMedId++,
      name: 'Metformin',
      dosage: '850mg',
      scheduleType: 'once_daily',
      totalPills: 30,
      pillsRemaining: 22,
      isActive: true,
    );
    _medications.add(med2);

    _doseEvents.add(
      MockDoseEvent(id: _nextDoseId++, medicationId: med2.id, scheduledTime: today8am, status: 'taken'),
    );

    // Medication 3: Ibuprofen
    final med3 = MockMedication(
      id: _nextMedId++,
      name: 'Ibuprofen',
      dosage: '400mg',
      scheduleType: 'every_x_hours',
      totalPills: 12,
      pillsRemaining: 6,
      isActive: true,
    );
    _medications.add(med3);

    _doseEvents.addAll([
      MockDoseEvent(id: _nextDoseId++, medicationId: med3.id, scheduledTime: today8am, status: 'missed'),
      MockDoseEvent(id: _nextDoseId++, medicationId: med3.id, scheduledTime: today2pm, status: 'pending'),
    ]);
  }

  List<MockMedication> getMedications() => List.unmodifiable(_medications);

  List<MockDoseEvent> getTodaysDoses() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return _doseEvents.where((d) =>
      d.scheduledTime.isAfter(todayStart) && d.scheduledTime.isBefore(todayEnd)
    ).toList();
  }

  MockMedication? getMedicationById(int id) {
    try {
      return _medications.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  void confirmDose(int doseId) {
    try {
      final dose = _doseEvents.firstWhere((d) => d.id == doseId);
      dose.status = 'taken';
      final med = getMedicationById(dose.medicationId);
      if (med != null && med.pillsRemaining > 0) {
        med.pillsRemaining;
      }
    } catch (_) {}
  }

  void snoozeDose(int doseId) {
    try {
      final dose = _doseEvents.firstWhere((d) => d.id == doseId);
      dose.snoozeCount++;
    } catch (_) {}
  }

  void deleteMedication(int medId) {
    _medications.removeWhere((m) => m.id == medId);
    _doseEvents.removeWhere((d) => d.medicationId == medId);
  }

  int addMedication({
    required String name,
    required String dosage,
    required String scheduleType,
    int? totalPills,
  }) {
    final med = MockMedication(
      id: _nextMedId++,
      name: name,
      dosage: dosage,
      scheduleType: scheduleType,
      totalPills: totalPills ?? 0,
      pillsRemaining: totalPills ?? 0,
      isActive: true,
    );
    _medications.add(med);

    // Add some fake dose events for today
    final now = DateTime.now();
    final today9am = DateTime(now.year, now.month, now.day, 9, 0);
    final today6pm = DateTime(now.year, now.month, now.day, 18, 0);

    _doseEvents.add(
      MockDoseEvent(id: _nextDoseId++, medicationId: med.id, scheduledTime: today9am, status: 'pending'),
    );
    _doseEvents.add(
      MockDoseEvent(id: _nextDoseId++, medicationId: med.id, scheduledTime: today6pm, status: 'pending'),
    );

    return med.id;
  }
}

final mockRepositoryProvider = Provider<MockMedicationRepository>((ref) {
  return MockMedicationRepository();
});
