import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/database.dart';
import '../local/database_provider.dart';
import '../../services/alarm_service.dart';

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
      if (patients.isNotEmpty) return patients.first.id;
    }
    final userId = await _db.into(_db.users).insert(
      UsersCompanion.insert(name: 'My Medications', accountType: 'personal'),
    );
    final patientId = await _db.into(_db.patients).insert(
      PatientsCompanion.insert(name: 'Default', caregiverId: Value(userId)),
    );
    return patientId;
  }

  Future<int> saveMedication({
    required int patientId,
    required String name,
    required String dosage,
    String? form,
    double? strengthValue,
    String? strengthUnit,
    double? amountPerDose,
    String? amountUnit,
    String? quantityUnit,
    required String scheduleType,
    required DateTime startDateTime,
    int? totalPills,
    String? notes,
    String? photoPath,
    required List<Map<String, int>> times,
    required int intervalHours,
    required Set<String> customDays,
  }) async {
    final medicationId = await _db.into(_db.medications).insert(
      MedicationsCompanion.insert(
        patientId: patientId,
        name: name,
        dosage: dosage,
        form: Value(form ?? 'pills'),
        strengthValue: Value(strengthValue),
        strengthUnit: Value(strengthUnit),
        amountPerDose: Value(amountPerDose ?? 1),
        amountUnit: Value(amountUnit ?? 'tablet'),
        quantityUnit: Value(quantityUnit ?? 'tablets'),
        scheduleType: scheduleType,
        startDateTime: startDateTime,
        totalPills: totalPills ?? 0,
        pillsRemaining: totalPills ?? 0,
        notes: Value(notes),
        photoPath: Value(photoPath),
        isActive: const Value(true),
      ),
    );

    for (final time in times) {
      await _db.into(_db.scheduleTimes).insert(
        ScheduleTimesCompanion.insert(
          medicationId: medicationId,
          hour: Value(time['hour']),
          minute: Value(time['minute']),
          intervalHours: Value(scheduleType == 'every_x_hours' ? intervalHours : null),
          daysOfWeek: Value(scheduleType == 'custom' ? customDays.join(',') : null),
        ),
      );
    }

    await _generateDoseEvents(
      medicationId: medicationId, scheduleType: scheduleType,
      startDateTime: startDateTime, times: times,
      intervalHours: intervalHours, customDays: customDays, totalPills: totalPills,
    );

    final doseTimes = _getDoseTimes(scheduleType, startDateTime, times, intervalHours, customDays, totalPills);
    await AlarmService.scheduleMedicationAlarms(
        scheduleType: scheduleType,
        intervalHours: intervalHours,
      medicationId: medicationId, medicationName: name, dosage: dosage, doseTimes: doseTimes,
    );

    return medicationId;
  }

  Future<void> _generateDoseEvents({
    required int medicationId, required String scheduleType,
    required DateTime startDateTime, required List<Map<String, int>> times,
    required int intervalHours, required Set<String> customDays, int? totalPills,
  }) async {
    final doses = _getDoseTimes(scheduleType, startDateTime, times, intervalHours, customDays, totalPills);
    for (final doseTime in doses) {
      await _db.into(_db.doseEvents).insert(
        DoseEventsCompanion.insert(medicationId: medicationId, scheduledTime: doseTime, status: const Value('pending')),
      );
    }
  }

  List<DateTime> _getDoseTimes(String scheduleType, DateTime startDateTime, List<Map<String, int>> times, int intervalHours, Set<String> customDays, int? totalPills) {
    final List<DateTime> doseTimes = [];
    final endDate = DateTime(startDateTime.year, startDateTime.month, startDateTime.day + 7);
    switch (scheduleType) {
      case 'once_daily':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1)))
          doseTimes.add(DateTime(d.year, d.month, d.day, times[0]['hour']!, times[0]['minute']!));
        break;
      case 'multiple_times':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1)))
          for (final time in times)
            doseTimes.add(DateTime(d.year, d.month, d.day, time['hour']!, time['minute']!));
        break;
      case 'every_x_hours':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(Duration(hours: intervalHours)))
          doseTimes.add(d);
        break;
      case 'custom':
        const dayMap = {'MON': DateTime.monday, 'TUE': DateTime.tuesday, 'WED': DateTime.wednesday, 'THU': DateTime.thursday, 'FRI': DateTime.friday, 'SAT': DateTime.saturday, 'SUN': DateTime.sunday};
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1)))
          if (customDays.any((day) => dayMap[day] == d.weekday))
            doseTimes.add(DateTime(d.year, d.month, d.day, times[0]['hour']!, times[0]['minute']!));
        break;
    }
    final doses = totalPills != null && totalPills > 0 ? doseTimes.take(totalPills) : doseTimes;
    return doses.toList();
  }

  Future<List<Medication>> getMedications(int patientId) {
    final query = _db.select(_db.medications)..where((t) => t.patientId.equals(patientId))..where((t) => t.isActive.equals(true));
    return query.get();
  }

  Future<List<DoseEvent>> getTodaysDoses(int patientId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final query = _db.select(_db.doseEvents).join([innerJoin(_db.medications, _db.medications.id.equalsExp(_db.doseEvents.medicationId))])
      ..where(_db.medications.patientId.equals(patientId))
      ..where(_db.doseEvents.scheduledTime.isBetweenValues(todayStart, todayEnd));
    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.doseEvents)).toList();
  }

  Future<void> confirmDose(int doseId, int medicationId) async {
    final med = await (_db.select(_db.medications)..where((t) => t.id.equals(medicationId))).getSingle();
    await (_db.update(_db.doseEvents)..where((t) => t.id.equals(doseId))).write(DoseEventsCompanion(status: const Value('taken'), confirmedAt: Value(DateTime.now())));
    if (med.pillsRemaining > 0) {
      await (_db.update(_db.medications)..where((t) => t.id.equals(medicationId))).write(MedicationsCompanion(pillsRemaining: Value(med.pillsRemaining - 1)));
    }
  }

  Future<void> snoozeDose(int doseId) async {}
  Future<void> deleteMedication(int medicationId) async {
    await AlarmService.cancelMedicationAlarms(medicationId);
    await (_db.update(_db.medications)..where((t) => t.id.equals(medicationId))).write(const MedicationsCompanion(isActive: Value(false)));
  }

  Future<void> resetAllData() async {
    await _db.delete(_db.doseEvents).go();
    await _db.delete(_db.scheduleTimes).go();
    await _db.delete(_db.medications).go();
    await _db.delete(_db.patients).go();
    await _db.delete(_db.users).go();
  }

  Future<List<DoseEvent>> getDoseHistory(int medicationId) async {
    final query = _db.select(_db.doseEvents)..where((t) => t.medicationId.equals(medicationId));
    return query.get();
  }
}
