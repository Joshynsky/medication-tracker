import 'package:medication_tracker/data/local/database.dart';

/// Builds a [Medication] row directly (no DB round-trip) for pure-logic
/// unit tests. Mirrors the defaults `MedicationRepository.saveMedication`
/// applies, so fixtures look like real saved medications.
Medication buildMedication({
  int id = 1,
  int patientId = 1,
  String name = 'Test Medication',
  String dosage = '10mg',
  String form = 'pills',
  double? strengthValue,
  String? strengthUnit,
  double amountPerDose = 1,
  String amountUnit = 'tablet',
  String? photoPath,
  required String scheduleType,
  required DateTime startDateTime,
  int totalPills = 0,
  int pillsRemaining = 0,
  String quantityUnit = 'tablets',
  String? notes,
  bool isActive = true,
  DateTime? createdAt,
}) {
  return Medication(
    id: id,
    patientId: patientId,
    name: name,
    dosage: dosage,
    form: form,
    strengthValue: strengthValue,
    strengthUnit: strengthUnit,
    amountPerDose: amountPerDose,
    amountUnit: amountUnit,
    photoPath: photoPath,
    scheduleType: scheduleType,
    startDateTime: startDateTime,
    totalPills: totalPills,
    pillsRemaining: pillsRemaining,
    quantityUnit: quantityUnit,
    notes: notes,
    isActive: isActive,
    createdAt: createdAt ?? startDateTime,
  );
}

/// Builds a [DoseEvent] row directly (no DB round-trip) for pure-logic
/// unit tests.
DoseEvent buildDoseEvent({
  int id = 1,
  required int medicationId,
  required DateTime scheduledTime,
  String status = 'pending',
  DateTime? confirmedAt,
  int? takenLateMinutes,
  DateTime? createdAt,
}) {
  return DoseEvent(
    id: id,
    medicationId: medicationId,
    scheduledTime: scheduledTime,
    status: status,
    confirmedAt: confirmedAt,
    takenLateMinutes: takenLateMinutes,
    createdAt: createdAt ?? scheduledTime,
  );
}
