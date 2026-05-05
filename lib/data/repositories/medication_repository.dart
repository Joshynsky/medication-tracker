import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/database.dart';
import '../local/database_provider.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  final db = ref.read(databaseProvider);
  return MedicationRepository(db);
});

class MedicationRepository {
  final AppDatabase _db;

  MedicationRepository(this._db);

  Future<int> ensureDefaultUserAndPatient() async {
    final users = await _db.select(_db.users).get();
    if (users.isNotEmpty) {
      final patients = await _db.select(_db.patients).get();
      if (patients.isNotEmpty) {
        return patients.first.id;
      }
    }

    final userId = await _db.into(_db.users).insert(
      UsersCompanion.insert(
        name: 'My Medications',
        accountType: 'personal',
      ),
    );

    final patientId = await _db.into(_db.patients).insert(
      PatientsCompanion.insert(
        name: 'Default',
        caregiverId: Value(userId),
      ),
    );

    return patientId;
  }

  Future<int> saveMedication({
    required int patientId,
    required String name,
    required String dosage,
    required String scheduleType,
    required DateTime startDateTime,
    int? totalPills,
    String? notes,
    String? photoOuter,
    String? photoInner,
    String? photoPills,
    required List<Map<String, int>> times,
    required int intervalHours,
    required Set<String> customDays,
  }) async {
    final medicationId = await _db.into(_db.medications).insert(
      MedicationsCompanion.insert(
        patientId: patientId,
        name: name,
        dosage: dosage,
        scheduleType: scheduleType,
        startDateTime: startDateTime,
        totalPills: totalPills ?? 0,
        pillsRemaining: totalPills ?? 0,
        notes: Value(notes),
        photoPath: Value(photoOuter),
        isActive: const Value(true),
      ),
    );

    for (final time in times) {
      await _db.into(_db.scheduleTimes).insert(
        ScheduleTimesCompanion.insert(
          medicationId: medicationId,
          hour: Value(time['hour']),
          minute: Value(time['minute']),
          intervalHours: Value(
            scheduleType == 'every_x_hours' ? intervalHours : null,
          ),
          daysOfWeek: Value(
            scheduleType == 'custom' ? customDays.join(',') : null,
          ),
        ),
      );
    }

    await _generateDoseEvents(
      medicationId: medicationId,
      scheduleType: scheduleType,
      startDateTime: startDateTime,
      times: times,
      intervalHours: intervalHours,
      customDays: customDays,
      totalPills: totalPills,
    );

    return medicationId;
  }

  Future<void> _generateDoseEvents({
    required int medicationId,
    required String scheduleType,
    required DateTime startDateTime,
    required List<Map<String, int>> times,
    required int intervalHours,
    required Set<String> customDays,
    int? totalPills,
  }) async {
    final List<DateTime> doseTimes = [];
    final endDate = DateTime(startDateTime.year, startDateTime.month + 1, startDateTime.day);

    switch (scheduleType) {
      case 'once_daily':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1))) {
          doseTimes.add(DateTime(d.year, d.month, d.day, times[0]['hour']!, times[0]['minute']!));
        }
        break;

      case 'multiple_times':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1))) {
          for (final time in times) {
            doseTimes.add(DateTime(d.year, d.month, d.day, time['hour']!, time['minute']!));
          }
        }
        break;

      case 'every_x_hours':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(Duration(hours: intervalHours))) {
          doseTimes.add(d);
        }
        break;

      case 'custom':
        const dayMap = {
          'MON': DateTime.monday,
          'TUE': DateTime.tuesday,
          'WED': DateTime.wednesday,
          'THU': DateTime.thursday,
          'FRI': DateTime.friday,
          'SAT': DateTime.saturday,
          'SUN': DateTime.sunday,
        };
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1))) {
          if (customDays.any((day) => dayMap[day] == d.weekday)) {
            doseTimes.add(DateTime(d.year, d.month, d.day, times[0]['hour']!, times[0]['minute']!));
          }
        }
        break;
    }

    final doses = totalPills != null && totalPills > 0
        ? doseTimes.take(totalPills)
        : doseTimes;

    for (final doseTime in doses) {
      if (doseTime.isAfter(DateTime.now())) {
        await _db.into(_db.doseEvents).insert(
          DoseEventsCompanion.insert(
            medicationId: medicationId,
            scheduledTime: doseTime,
            status: const Value('pending'),
          ),
        );
      }
    }
  }

  Future<List<Medication>> getMedications(int patientId) {
    final query = _db.select(_db.medications)
      ..where((t) => t.patientId.equals(patientId))
      ..where((t) => t.isActive.equals(true));
    return query.get();
  }

  Future<List<DoseEvent>> getTodaysDoses(int patientId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final query = _db.select(_db.doseEvents).join([
      innerJoin(_db.medications, _db.medications.id.equalsExp(_db.doseEvents.medicationId)),
    ])
      ..where(_db.medications.patientId.equals(patientId))
      ..where(_db.doseEvents.scheduledTime.isBetweenValues(todayStart, todayEnd));

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.doseEvents)).toList();
  }
}
