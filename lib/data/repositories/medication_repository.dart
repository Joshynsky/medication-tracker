import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/database.dart';
import '../local/database_provider.dart';
import '../../services/alarm_service.dart';
import '../../shared/schedule_days.dart';

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

    final createdDoses = await _generateDoseEvents(
      medicationId: medicationId, scheduleType: scheduleType,
      startDateTime: startDateTime, times: times,
      intervalHours: intervalHours, customDays: customDays, totalPills: totalPills,
    );

    await AlarmService.scheduleMedicationAlarms(
        scheduleType: scheduleType,
        intervalHours: intervalHours,
        minutesOfDay: _minutesOfDay(times),
      medicationId: medicationId, medicationName: name, dosage: dosage, doses: createdDoses,
    );

    return medicationId;
  }

  /// Sorted hour*60+minute list for every configured time-of-day -- only
  /// meaningful for `multiple_times` (see [scheduleCycleMinutes]), harmless
  /// to compute and pass for other schedule types since they ignore it.
  List<int> _minutesOfDay(List<Map<String, int>> times) =>
      times.map((t) => (t['hour'] ?? 0) * 60 + (t['minute'] ?? 0)).toList()..sort();

  /// Cancels every still-pending notification for each of a medication's
  /// dose events. Used before regenerating a schedule (edit) or deactivating
  /// a medication (delete), so stale alarms don't linger.
  Future<void> _cancelAllAlarmsFor(int medicationId) async {
    final doses = await (_db.select(
      _db.doseEvents,
    )..where((t) => t.medicationId.equals(medicationId))).get();
    for (final dose in doses) {
      await AlarmService.cancelDoseAlarms(dose.id);
    }
  }

  /// Updates an existing medication's details and schedule. Only PENDING
  /// dose events are cleared and regenerated against the edited schedule --
  /// already-taken doses (and the pill count they consumed) are preserved as
  /// history, not touched. Existing alarms are cancelled and replaced with
  /// ones matching the new schedule.
  Future<void> updateMedication({
    required int medicationId,
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
    final med = await (_db.select(
      _db.medications,
    )..where((t) => t.id.equals(medicationId))).getSingle();

    await _cancelAllAlarmsFor(medicationId);
    await (_db.delete(_db.doseEvents)..where(
      (t) => t.medicationId.equals(medicationId) & t.status.equals('pending'),
    )).go();
    await (_db.delete(
      _db.scheduleTimes,
    )..where((t) => t.medicationId.equals(medicationId))).go();

    final newTotalPills = totalPills ?? med.totalPills;
    final pillsTaken = med.totalPills - med.pillsRemaining;
    final newPillsRemaining = (newTotalPills - pillsTaken).clamp(0, newTotalPills);

    await (_db.update(_db.medications)..where((t) => t.id.equals(medicationId)))
        .write(
      MedicationsCompanion(
        name: Value(name),
        dosage: Value(dosage),
        form: Value(form ?? 'pills'),
        strengthValue: Value(strengthValue),
        strengthUnit: Value(strengthUnit),
        amountPerDose: Value(amountPerDose ?? 1),
        amountUnit: Value(amountUnit ?? 'tablet'),
        quantityUnit: Value(quantityUnit ?? 'tablets'),
        scheduleType: Value(scheduleType),
        startDateTime: Value(startDateTime),
        totalPills: Value(newTotalPills),
        pillsRemaining: Value(newPillsRemaining),
        notes: Value(notes),
        photoPath: Value(photoPath),
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

    final createdDoses = await _generateDoseEvents(
      medicationId: medicationId, scheduleType: scheduleType,
      startDateTime: startDateTime, times: times,
      intervalHours: intervalHours, customDays: customDays,
      totalPills: newTotalPills > 0 ? newPillsRemaining : null,
    );

    await AlarmService.scheduleMedicationAlarms(
      scheduleType: scheduleType,
      intervalHours: intervalHours,
      minutesOfDay: _minutesOfDay(times),
      medicationId: medicationId, medicationName: name, dosage: dosage, doses: createdDoses,
    );
  }

  /// Inserts a DoseEvent row per generated dose time and returns each one's
  /// (doseId, scheduledTime) pair, so callers (AlarmService) can embed the
  /// real doseId in each scheduled notification's payload -- without this,
  /// there'd be no way to know which dose a notification action applies to.
  Future<List<ScheduledDose>> _generateDoseEvents({
    required int medicationId, required String scheduleType,
    required DateTime startDateTime, required List<Map<String, int>> times,
    required int intervalHours, required Set<String> customDays, int? totalPills,
  }) async {
    final doseTimes = _getDoseTimes(scheduleType, startDateTime, times, intervalHours, customDays, totalPills);
    final created = <ScheduledDose>[];
    for (final doseTime in doseTimes) {
      final doseId = await _db.into(_db.doseEvents).insert(
        DoseEventsCompanion.insert(medicationId: medicationId, scheduledTime: doseTime, status: const Value('pending')),
      );
      created.add(ScheduledDose(doseId: doseId, time: doseTime));
    }
    return created;
  }

  List<DateTime> _getDoseTimes(String scheduleType, DateTime startDateTime, List<Map<String, int>> times, int intervalHours, Set<String> customDays, int? totalPills) {
    final List<DateTime> doseTimes = [];
    final endDate = DateTime(startDateTime.year, startDateTime.month, startDateTime.day + 7);
    switch (scheduleType) {
      case 'once_daily':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1))) {
          doseTimes.add(DateTime(d.year, d.month, d.day, times[0]['hour']!, times[0]['minute']!));
        }
        break;
      case 'multiple_times':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1)))
          for (final time in times) {
            doseTimes.add(DateTime(d.year, d.month, d.day, time['hour']!, time['minute']!));
          }
        break;
      case 'every_x_hours':
        {
          // Anchor on times[0] (hour/minute), matching once_daily/multiple_times/
          // custom -- startDateTime only contributes its date. Previously this
          // used startDateTime directly (date AND time-of-day), which silently
          // ignored the "Starting at" time shown in the wizard and disagreed
          // with the dashboard's own every_x_hours anchor (getExpectedDoseTimesToday
          // in dashboard_logic.dart, which has always read times[0]).
          final anchor = DateTime(
            startDateTime.year, startDateTime.month, startDateTime.day,
            times[0]['hour']!, times[0]['minute']!,
          );
          for (var d = anchor; d.isBefore(endDate); d = d.add(Duration(hours: intervalHours))) {
            doseTimes.add(d);
          }
        }
        break;
      case 'custom':
        for (var d = startDateTime; d.isBefore(endDate); d = d.add(const Duration(days: 1))) {
          if (customDays.any((day) => scheduleDayAbbreviations[day] == d.weekday)) {
            doseTimes.add(DateTime(d.year, d.month, d.day, times[0]['hour']!, times[0]['minute']!));
        }
          }
        break;
    }
    final doses = totalPills != null && totalPills > 0 ? doseTimes.take(totalPills) : doseTimes;
    return doses.toList();
  }

  /// Whether the notification-permission onboarding moment has already been
  /// shown (see [markOnboardingSeen]). There's always at most one user row
  /// in this single-user app; `false` if it doesn't exist yet.
  Future<bool> hasSeenOnboarding() async {
    final users = await _db.select(_db.users).get();
    if (users.isEmpty) return false;
    return users.first.hasSeenOnboarding;
  }

  /// Marks the notification-permission onboarding moment as shown, so it
  /// isn't shown again. No-op if the user row doesn't exist yet.
  Future<void> markOnboardingSeen() async {
    final users = await _db.select(_db.users).get();
    if (users.isEmpty) return;
    await (_db.update(_db.users)..where((t) => t.id.equals(users.first.id)))
        .write(const UsersCompanion(hasSeenOnboarding: Value(true)));
  }

  Future<List<Medication>> getMedications(int patientId) {
    final query = _db.select(_db.medications)..where((t) => t.patientId.equals(patientId))..where((t) => t.isActive.equals(true));
    return query.get();
  }

  /// Fetches each medication's ScheduleTimes rows in one query, keyed by
  /// medicationId. Used by the dashboard so it can judge each medication's
  /// doses against its own configured schedule (times/interval/days),
  /// instead of guessing from the Medication row alone.
  Future<Map<int, List<ScheduleTime>>> getScheduleTimesForMedications(
    List<int> medicationIds,
  ) async {
    if (medicationIds.isEmpty) return {};
    final query = _db.select(_db.scheduleTimes)
      ..where((t) => t.medicationId.isIn(medicationIds));
    final rows = await query.get();
    final byMedicationId = <int, List<ScheduleTime>>{};
    for (final row in rows) {
      byMedicationId.putIfAbsent(row.medicationId, () => []).add(row);
    }
    return byMedicationId;
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
    // Otherwise a "missed dose" notification could still fire later for a
    // dose that's already been taken.
    await AlarmService.cancelDoseAlarms(doseId);
  }

  /// Reschedules the dose's reminder 10 minutes from now. Doesn't change
  /// the dose's status -- it's still 'pending' until actually confirmed;
  /// snoozing just delays the next nudge.
  Future<void> snoozeDose(int doseId) async {
    final dose = await (_db.select(
      _db.doseEvents,
    )..where((t) => t.id.equals(doseId))).getSingleOrNull();
    if (dose == null) return;

    final med = await (_db.select(
      _db.medications,
    )..where((t) => t.id.equals(dose.medicationId))).getSingleOrNull();
    if (med == null) return;

    await AlarmService.scheduleSnoozeAlarm(
      doseId: dose.id,
      medicationId: med.id,
      medicationName: med.name,
      dosage: med.dosage,
    );
  }

  Future<void> deleteMedication(int medicationId) async {
    await _cancelAllAlarmsFor(medicationId);
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
