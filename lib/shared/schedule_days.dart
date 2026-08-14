/// Maps the day-of-week abbreviations used by `custom` schedules (stored,
/// comma-separated, in `ScheduleTimes.daysOfWeek`, e.g. "MON,WED,FRI") to
/// `DateTime`'s weekday constants.
///
/// Shared between `MedicationRepository` (dose-event generation) and
/// `DashboardLogic` (today's expected-dose-time calculation) so the two
/// don't drift into their own independent, possibly-inconsistent copies --
/// see KNOWN_ISSUES.md for what happened last time this app had two copies
/// of the same lookup (the window-size formula).
const Map<String, int> scheduleDayAbbreviations = {
  'MON': DateTime.monday,
  'TUE': DateTime.tuesday,
  'WED': DateTime.wednesday,
  'THU': DateTime.thursday,
  'FRI': DateTime.friday,
  'SAT': DateTime.saturday,
  'SUN': DateTime.sunday,
};
