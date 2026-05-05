import 'package:drift/drift.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get accountType => text()(); // 'personal' or 'caregiver'
  TextColumn get supabaseId => text().nullable()();
  BoolColumn get hasSeenOnboarding => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}