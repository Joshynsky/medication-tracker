import 'package:drift/drift.dart';
import 'medications_table.dart';

class DoseEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId => integer().references(Medications, #id)();
  DateTimeColumn get scheduledTime => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  IntColumn get takenLateMinutes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
