import 'package:collection/collection.dart';
import '../../data/local/database.dart';
import '../../shared/schedule_window.dart';

/// Pure, Flutter-free scheduling/status logic used by [DashboardScreen].
///
/// Extracted verbatim from `_DashboardScreenState` so it can be unit tested
/// without pumping widgets. Behavior (including known bugs) is preserved
/// exactly as it was inline; see test/unit/dashboard_logic_test.dart for
/// coverage, including tests that document known bugs on purpose.
class DashboardLogic {
  DashboardLogic._();

  static int windowMinutes(String scheduleType, int intervalHours) =>
      scheduleWindowMinutes(scheduleType, intervalHours);

  static bool isInWindow(
    DateTime now,
    DateTime t,
    String scheduleType,
    int intervalHours,
  ) {
    return t.difference(now).inMinutes.abs() <=
        windowMinutes(scheduleType, intervalHours);
  }

  static bool isPastWindow(
    DateTime now,
    DateTime t,
    String scheduleType,
    int intervalHours,
  ) {
    return now.difference(t).inMinutes >
        windowMinutes(scheduleType, intervalHours);
  }

  static String formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final am = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }

  static List<DateTime> getExpectedDoseTimesToday(Medication med, DateTime now) {
    final times = <DateTime>[];
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final startHour = med.startDateTime.hour;
    final startMinute = med.startDateTime.minute;

    if (med.scheduleType == 'once_daily') {
      times.add(
        DateTime(today.year, today.month, today.day, startHour, startMinute),
      );
      return times;
    }

    if (med.scheduleType == 'every_x_hours') {
      int intervalH = 4; // Default, will be overridden
      // Calculate backwards from start time to find today's anchor
      var anchor = med.startDateTime;
      while (anchor.isAfter(today)) {
        anchor = anchor.subtract(Duration(hours: intervalH));
      }
      while (anchor.add(Duration(hours: intervalH)).isBefore(today) ||
          anchor.isBefore(today)) {
        anchor = anchor.add(Duration(hours: intervalH));
      }
      // Generate all times for today
      var d = anchor;
      while (d.isBefore(tomorrow)) {
        if (d.isAfter(today) || d == today) {
          times.add(DateTime(d.year, d.month, d.day, d.hour, d.minute));
        }
        d = d.add(Duration(hours: intervalH));
      }
      return times;
    }

    // Default: just the start time
    times.add(
      DateTime(today.year, today.month, today.day, startHour, startMinute),
    );
    return times;
  }

  /// Builds the dashboard's time-dot statuses. `schedType`/`intervalH` are a
  /// single, shared window computed once by the caller (from whichever
  /// medication owns the "next dose") and applied to every medication's
  /// dots here, rather than each medication's own schedule/window. See the
  /// "cross-medication window bug" test for the consequence.
  static Map<String, String> computeTimeDots({
    required List<Medication> meds,
    required List<DoseEvent> doses,
    required DateTime now,
    required String schedType,
    required int intervalH,
  }) {
    final timeDots = <String, String>{};
    for (final med in meds) {
      final medDoses = doses.where((d) => d.medicationId == med.id).toList();
      final expectedTimes = getExpectedDoseTimesToday(med, now);
      for (final expectedTime in expectedTimes) {
        final k = formatTime(expectedTime);
        final existingDose = medDoses.firstWhereOrNull(
          (d) =>
              d.scheduledTime.hour == expectedTime.hour &&
              d.scheduledTime.minute == expectedTime.minute,
        );
        if (existingDose != null) {
          if (existingDose.status == 'pending' &&
              now.difference(existingDose.scheduledTime).inMinutes >
                  windowMinutes(schedType, intervalH)) {
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
