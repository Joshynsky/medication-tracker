import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
      for (final table in allTables) {
        await m.deleteTable(table.actualTableName);
      }
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
