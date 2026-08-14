/// Single source of truth for dose timing math -- shared between the
/// dashboard's dot/status logic ([DashboardLogic]) and `AlarmService`'s
/// notification scheduling. These previously duplicated formulas
/// independently and had drifted out of sync -- see KNOWN_ISSUES.md.
///
/// Everything here scales off [scheduleCycleMinutes]: the realistic gap
/// between one dose and the next. A medication taken every 2 hours needs a
/// much tighter on-time window (and an earlier-relative "coming up"
/// reminder) than one taken once a day -- so rather than a flat per-
/// schedule-type constant, window/reminder sizes are a fraction of that gap,
/// capped so a once-daily dose doesn't get an unrealistic multi-hour window.
library;

/// The gap (in minutes) between this dose and the next one for [scheduleType].
///
/// [minutesOfDay] is the sorted list of hour*60+minute values for every
/// configured time-of-day -- only meaningful (and only used) for
/// `multiple_times`, where the gap is the smallest interval between any two
/// consecutive configured times (wrapping past midnight back to the first
/// time of the next day). Ignored for other schedule types.
int scheduleCycleMinutes(
  String scheduleType,
  int intervalHours, [
  List<int> minutesOfDay = const [],
]) {
  switch (scheduleType) {
    case 'every_x_hours':
      return intervalHours > 0 ? intervalHours * 60 : 24 * 60;
    case 'multiple_times':
      if (minutesOfDay.length < 2) return 24 * 60;
      final sorted = [...minutesOfDay]..sort();
      var minGap = 24 * 60;
      for (var i = 0; i < sorted.length; i++) {
        final isLast = i == sorted.length - 1;
        final gap = isLast
            ? (24 * 60 - sorted[i]) + sorted.first
            : sorted[i + 1] - sorted[i];
        if (gap < minGap) minGap = gap;
      }
      return minGap;
    case 'once_daily':
    case 'custom':
    default:
      return 24 * 60;
  }
}

/// The on-time window, in minutes on *each side* of the dose time (e.g. a
/// return value of 30 means the window spans dose-30min to dose+30min).
/// Capped at 30 minutes -- beyond that, a wider window stops meaningfully
/// helping and just makes "on time" mean less.
int scheduleWindowMinutes(
  String scheduleType,
  int intervalHours, [
  List<int> minutesOfDay = const [],
]) {
  final cycle = scheduleCycleMinutes(scheduleType, intervalHours, minutesOfDay);
  final window = cycle ~/ 12;
  return window < 30 ? window : 30;
}

/// How long before the dose time the "coming up" reminder fires. Always
/// inside the window (strictly less than [windowMinutes], so it can never
/// fire before the window itself opens), capped at 10 minutes.
int scheduleReminderMinutesBefore(int windowMinutes) {
  final reminder = windowMinutes ~/ 3;
  return reminder < 10 ? reminder : 10;
}
