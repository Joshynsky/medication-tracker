import 'package:drift/drift.dart';
import 'patients_table.dart';

class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get patientId => integer().references(Patients, #id)();
  TextColumn get name => text()();
  TextColumn get dosage => text()();
  TextColumn get form => text().withDefault(const Constant('pills'))(); // pills, liquid, ointment, injection, drops, patch, other
  RealColumn get strengthValue => real().nullable()();
  TextColumn get strengthUnit => text().nullable()(); // mg, mcg, g, ml, tbsp, tsp, etc.
  RealColumn get amountPerDose => real().withDefault(const Constant(1))(); // e.g., 1 tablet, 2 tablets
  TextColumn get amountUnit => text().withDefault(const Constant('tablet'))(); // tablet, teaspoon, ml, etc.
  TextColumn get photoPath => text().nullable()();
  TextColumn get scheduleType => text()();
  DateTimeColumn get startDateTime => dateTime()();
  IntColumn get totalPills => integer()();
  IntColumn get pillsRemaining => integer()();
  TextColumn get quantityUnit => text().withDefault(const Constant('tablets'))(); // tablets, ml, etc.
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
