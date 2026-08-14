import 'package:collection/collection.dart';
import '../../data/local/database.dart';
import '../../shared/schedule_days.dart';
import '../../shared/schedule_window.dart';

/// Pure, Flutter-free scheduling/status logic used by [DashboardScreen].
///
/// Extracted out of `_DashboardScreenState` so it can be unit tested without
/// pumping widgets; see test/unit/dashboard_logic_test.dart for coverage.
///
/// `getExpectedDoseTimesToday`/`computeTimeDots` read each medication's own
/// [ScheduleTime] rows (hour/minute per configured time, the real configured
/// interval, and configured days for `custom` schedules) rather than just
/// the `Medication` row -- see KNOWN_ISSUES.md for the bugs this fixed
/// (multi-dose/custom schedules, the hardcoded every_x_hours interval, the
/// cross-medication window bug, and once_daily's startDateTime/ScheduleTimes
/// mismatch).
class DashboardLogic {
  DashboardLogic._();

  static int windowMinutes(
    String scheduleType,
    int intervalHours, [
    List<int> minutesOfDay = const [],
  ]) => scheduleWindowMinutes(scheduleType, intervalHours, minutesOfDay);

  /// Sorted hour*60+minute list for every configured time-of-day -- only
  /// meaningful for `multiple_times` (see [scheduleCycleMinutes] in
  /// schedule_window.dart), harmless to compute and pass for other schedule
  /// types since they ignore it.
  static List<int> minutesOfDayFor(List<ScheduleTime> scheduleTimes) =>
      scheduleTimes
          .where((t) => t.hour != null && t.minute != null)
          .map((t) => t.hour! * 60 + t.minute!)
          .toList()
        ..sort();

  static bool isInWindow(
    DateTime now,
    DateTime t,
    String scheduleType,
    int intervalHours, [
    List<int> minutesOfDay = const [],
  ]) {
    return t.difference(now).inMinutes.abs() <=
        windowMinutes(scheduleType, intervalHours, minutesOfDay);
  }

  static bool isPastWindow(
    DateTime now,
    DateTime t,
    String scheduleType,
    int intervalHours, [
    List<int> minutesOfDay = const [],
  ]) {
    return now.difference(t).inMinutes >
        windowMinutes(scheduleType, intervalHours, minutesOfDay);
  }

  static String formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final am = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }

  /// The medication's own configured `every_x_hours` interval, read from its
  /// ScheduleTimes rows (only `every_x_hours` schedules ever have this set).
  /// Falls back to 0 if unavailable -- shouldn't happen in practice (the
  /// wizard always sets it for this schedule type), but avoids guessing.
  static int intervalHoursForEveryXHours(List<ScheduleTime> scheduleTimes) {
    final match = scheduleTimes.firstWhereOrNull((s) => s.intervalHours != null);
    return match?.intervalHours ?? 0;
  }

  /// The on-time window size for a specific medication, using its own
  /// schedule type and (for `every_x_hours`) its own configured interval.
  static int windowMinutesForMedication(
    Medication med,
    List<ScheduleTime> scheduleTimes,
  ) {
    final intervalHours = med.scheduleType == 'every_x_hours'
        ? intervalHoursForEveryXHours(scheduleTimes)
        : 0;
    return scheduleWindowMinutes(
      med.scheduleType,
      intervalHours,
      minutesOfDayFor(scheduleTimes),
    );
  }

  /// Expected dose times for [med] today, given its own ScheduleTimes rows.
  ///
  /// Returns an empty list if [scheduleTimes] is empty or doesn't contain
  /// the data a schedule type needs (missing hour/minute, missing interval
  /// for `every_x_hours`, missing days for `custom`) -- treated as "nothing
  /// scheduled" rather than guessed from `med.startDateTime`, which isn't a
  /// reliable source of the actually-configured dose time.
  static List<DateTime> getExpectedDoseTimesToday(
    Medication med,
    List<ScheduleTime> scheduleTimes,
    DateTime now,
  ) {
    if (scheduleTimes.isEmpty) return [];

    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    switch (med.scheduleType) {
      case 'once_daily':
        {
          final t = scheduleTimes.first;
          if (t.hour == null || t.minute == null) return [];
          return [DateTime(today.year, today.month, today.day, t.hour!, t.minute!)];
        }

      case 'multiple_times':
        return scheduleTimes
            .where((t) => t.hour != null && t.minute != null)
            .map(
              (t) => DateTime(today.year, today.month, today.day, t.hour!, t.minute!),
            )
            .toList();

      case 'every_x_hours':
        {
          final t = scheduleTimes.first;
          if (t.hour == null || t.minute == null || t.intervalHours == null) {
            return [];
          }
          final intervalH = t.intervalHours!;
          if (intervalH <= 0) return [];

          final times = <DateTime>[];
          // Anchor at today's configured hour/minute, then walk backwards to
          // find the start of today's cycle, then forwards across the day.
          var anchor = DateTime(today.year, today.month, today.day, t.hour!, t.minute!);
          while (anchor.isAfter(today)) {
            anchor = anchor.subtract(Duration(hours: intervalH));
          }
          while (anchor.add(Duration(hours: intervalH)).isBefore(today) ||
              anchor.isBefore(today)) {
            anchor = anchor.add(Duration(hours: intervalH));
          }
          var d = anchor;
          while (d.isBefore(tomorrow)) {
            if (d.isAfter(today) || d == today) {
              times.add(DateTime(d.year, d.month, d.day, d.hour, d.minute));
            }
            d = d.add(Duration(hours: intervalH));
          }
          return times;
        }

      case 'custom':
        {
          final t = scheduleTimes.first;
          if (t.hour == null || t.minute == null || t.daysOfWeek == null) {
            return [];
          }
          final configuredDays = t.daysOfWeek!
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty);
          final isTodayConfigured = configuredDays.any(
            (day) => scheduleDayAbbreviations[day] == now.weekday,
          );
          if (!isTodayConfigured) return [];
          return [DateTime(today.year, today.month, today.day, t.hour!, t.minute!)];
        }

      default:
        return [];
    }
  }

  /// Builds the dashboard's time-dot statuses. Each medication is judged
  /// against its own schedule type and window (via [windowMinutesForMedication]),
  /// not a single window shared across all medications.
  static Map<String, String> computeTimeDots({
    required List<Medication> meds,
    required List<DoseEvent> doses,
    required DateTime now,
    required Map<int, List<ScheduleTime>> scheduleTimesByMedicationId,
  }) {
    final timeDots = <String, String>{};
    for (final med in meds) {
      final medScheduleTimes = scheduleTimesByMedicationId[med.id] ?? const [];
      final medDoses = doses.where((d) => d.medicationId == med.id).toList();
      final expectedTimes = getExpectedDoseTimesToday(med, medScheduleTimes, now);
      final medWindowMinutes = windowMinutesForMedication(med, medScheduleTimes);
      for (final expectedTime in expectedTimes) {
        final k = formatTime(expectedTime);
        final existingDose = medDoses.firstWhereOrNull(
          (d) =>
              d.scheduledTime.hour == expectedTime.hour &&
              d.scheduledTime.minute == expectedTime.minute,
        );
        if (existingDose != null) {
          if (existingDose.status == 'pending' &&
              now.difference(existingDose.scheduledTime).inMinutes > medWindowMinutes) {
            // Past window but not taken = missed
            if (timeDots[k] != 'taken') timeDots[k] = 'missed';
          } else if (timeDots[k] != 'taken') {
            timeDots[k] = existingDose.status;
          }
        }
      }
    }
    return timeDots;
  }
}
