/// The on-time "window" size (in minutes) for a dose of the given schedule
/// type, used to judge whether a dose is early/on-time/missed.
///
/// Single source of truth, shared between the dashboard's dot/status logic
/// ([DashboardLogic.windowMinutes]) and `AlarmService`'s notification
/// scheduling. These previously duplicated this formula independently and
/// had drifted out of sync (÷5 vs ÷6 for `every_x_hours`) -- see
/// KNOWN_ISSUES.md.
///
/// TODO(future improvement, not yet built): window size is currently the
/// same for every medication of a given scheduleType. A real
/// per-medication-configurable window (e.g. a patient/caregiver choosing how
/// strict "on time" means for a specific medication) is a known future
/// improvement.
int scheduleWindowMinutes(String scheduleType, int intervalHours) {
  switch (scheduleType) {
    case 'every_x_hours':
      return (intervalHours * 60) ~/ 5;
    case 'once_daily':
      return 120;
    default:
      return 60;
  }
}
