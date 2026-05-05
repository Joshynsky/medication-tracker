import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'tables/users_table.dart';
import 'tables/patients_table.dart';
import 'tables/medications_table.dart';
import 'tables/schedule_times_table.dart';
import 'tables/dose_events_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Patients,
    Medications,
    ScheduleTimes,
    DoseEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // Delete all tables and recreate since we have no user data
      await m.deleteAll();
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'meditrack.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}