import 'package:drift/drift.dart';

class ScheduleTimes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicationId => integer().references(Medications, #id)();
  IntColumn get hour => integer().nullable()();
  IntColumn get minute => integer().nullable()();
  IntColumn get intervalHours => integer().nullable()();
  TextColumn get daysOfWeek => text().nullable()(); // 'MON,WED,FRI'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
