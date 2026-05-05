import 'package:drift/drift.dart';

class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get patientId => integer().references(Patients, #id)();
  TextColumn get name => text()();
  TextColumn get dosage => text()();
  TextColumn get photoPath => text().nullable()();
  TextColumn get scheduleType => text()(); // 'once_daily', 'multiple_times', 'interval', 'custom'
  DateTimeColumn get startDateTime => dateTime()();
  IntColumn get totalPills => integer()();
  IntColumn get pillsRemaining => integer()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
