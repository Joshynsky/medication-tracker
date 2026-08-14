// Unit tests for the dashboard's window/dose-status logic, extracted from
// `_DashboardScreenState` into lib/features/dashboard/dashboard_logic.dart
// specifically so it could be tested here without pumping widgets.
//
// getExpectedDoseTimesToday/computeTimeDots previously only had access to
// the Medication row, which caused several bugs documented in
// KNOWN_ISSUES.md (multi-dose/custom schedules, hardcoded every_x_hours
// interval, cross-medication window bug, once_daily/startDateTime
// mismatch). Fixed in "Fix the ScheduleTimes architecture gap"
// (2026-08-13) by threading each medication's own ScheduleTimes rows
// through. The tests below now assert the CORRECT behavior and pass.
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/features/dashboard/dashboard_logic.dart';

import 'fixtures.dart';

void main() {
  group('windowMinutes', () {
    test('once_daily is always 30 minutes regardless of intervalHours', () {
      expect(DashboardLogic.windowMinutes('once_daily', 6), 30);
      expect(DashboardLogic.windowMinutes('once_daily', 999), 30);
    });

    test('every_x_hours scales with the interval, capped at 30 minutes', () {
      expect(DashboardLogic.windowMinutes('every_x_hours', 4), 20);
      expect(DashboardLogic.windowMinutes('every_x_hours', 6), 30);
      expect(DashboardLogic.windowMinutes('every_x_hours', 2), 10);
    });

    test('other schedule types (multiple_times, custom, unknown) default to 30 minutes', () {
      expect(DashboardLogic.windowMinutes('multiple_times', 6), 30);
      expect(DashboardLogic.windowMinutes('custom', 6), 30);
      expect(DashboardLogic.windowMinutes('anything_else', 6), 30);
    });
  });

  group('isInWindow', () {
    test('true when now is before the scheduled time but within the window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 8, 45); // 15 min before, window=30
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isTrue);
    });

    test('true when now is after the scheduled time but within the window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 9, 15); // 15 min after, window=30
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isTrue);
    });

    test('false when outside the window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 12, 0); // 180 min after, window=30
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isFalse);
    });

    test('boundary: exactly at the window edge counts as in-window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 9, 30); // exactly 30 min, window=30
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isTrue);
    });
  });

  group('isPastWindow', () {
    test('false before the window closes', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 9, 20); // 20 min after, window=30
      expect(DashboardLogic.isPastWindow(now, scheduled, 'once_daily', 0), isFalse);
    });

    test('true once the window has closed', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 9, 45); // 45 min after, window=30
      expect(DashboardLogic.isPastWindow(now, scheduled, 'once_daily', 0), isTrue);
    });

    test('is one-directional: a dose scheduled in the future is never "past window"', () {
      final scheduled = DateTime(2026, 3, 10, 12, 0);
      final now = DateTime(2026, 3, 10, 9, 0); // 3 hours before it's even due
      expect(DashboardLogic.isPastWindow(now, scheduled, 'once_daily', 0), isFalse);
    });
  });

  group('formatTime', () {
    test('formats midnight as 12:00 AM', () {
      expect(DashboardLogic.formatTime(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    });

    test('formats noon as 12:00 PM', () {
      expect(DashboardLogic.formatTime(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    });

    test('formats an afternoon hour correctly, zero-padding minutes', () {
      expect(DashboardLogic.formatTime(DateTime(2026, 1, 1, 14, 5)), '2:05 PM');
    });
  });

  group('intervalHoursForEveryXHours', () {
    test("reads the interval from the medication's ScheduleTimes row", () {
      final scheduleTimes = [
        buildScheduleTime(medicationId: 1, hour: 8, minute: 0, intervalHours: 6),
      ];
      expect(DashboardLogic.intervalHoursForEveryXHours(scheduleTimes), 6);
    });

    test('falls back to 0 when no row has an interval set', () {
      final scheduleTimes = [buildScheduleTime(medicationId: 1, hour: 8, minute: 0)];
      expect(DashboardLogic.intervalHoursForEveryXHours(scheduleTimes), 0);
    });
  });

  group('windowMinutesForMedication', () {
    test('once_daily always returns 30, regardless of ScheduleTimes', () {
      final med = buildMedication(
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 1, 1, 8, 0),
      );
      expect(DashboardLogic.windowMinutesForMedication(med, const []), 30);
    });

    test('every_x_hours derives the window from its OWN configured interval', () {
      final med = buildMedication(
        scheduleType: 'every_x_hours',
        startDateTime: DateTime(2026, 1, 1, 8, 0),
      );
      final scheduleTimes = [
        buildScheduleTime(medicationId: med.id, hour: 8, minute: 0, intervalHours: 4),
      ];
      expect(DashboardLogic.windowMinutesForMedication(med, scheduleTimes), 20);
    });
  });

  group('getExpectedDoseTimesToday', () {
    test('once_daily returns exactly one time today, at the ScheduleTimes-configured hour/minute', () {
      final now = DateTime(2026, 3, 10, 15, 0);
      final med = buildMedication(
        id: 1,
        scheduleType: 'once_daily',
        startDateTime: DateTime(2025, 1, 1, 8, 30),
      );
      final scheduleTimes = [
        buildScheduleTime(medicationId: med.id, hour: 8, minute: 30),
      ];
      final times = DashboardLogic.getExpectedDoseTimesToday(med, scheduleTimes, now);
      expect(times, [DateTime(2026, 3, 10, 8, 30)]);
    });

    // --- FIXED BUG (found while wiring in ScheduleTimes, "Fix the
    // ScheduleTimes architecture gap" conversation, 2026-08-13): once_daily
    // used to read its dose time from med.startDateTime.hour/minute, a
    // separate, independently-set wizard field (the "Start date & time"
    // picker) from the actual configured dose time (the "Take at" picker,
    // which writes to ScheduleTimes) -- the two can genuinely disagree.
    test(
      'once_daily uses the ScheduleTimes-configured time, not startDateTime, '
      'when the two disagree',
      () {
        final now = DateTime(2026, 3, 10, 15, 0);
        final med = buildMedication(
          id: 1,
          scheduleType: 'once_daily',
          // startDateTime's time-of-day (14:32) does NOT match the
          // actually-configured dose time below (8:00).
          startDateTime: DateTime(2026, 3, 1, 14, 32),
        );
        final scheduleTimes = [
          buildScheduleTime(medicationId: med.id, hour: 8, minute: 0),
        ];
        final times = DashboardLogic.getExpectedDoseTimesToday(med, scheduleTimes, now);
        expect(
          times,
          [DateTime(2026, 3, 10, 8, 0)],
          reason: "the dose time should come from ScheduleTimes (8:00), not "
              "startDateTime's incidental time-of-day (14:32)",
        );
      },
    );

    // --- FIXED BUG #1 (KNOWN_ISSUES.md): multiple_times now returns every
    // configured dose time today, read from its own ScheduleTimes rows,
    // instead of always exactly one.
    test('multiple_times returns every configured dose time today', () {
      final now = DateTime(2026, 3, 10, 15, 0);
      final med = buildMedication(
        id: 1,
        scheduleType: 'multiple_times',
        startDateTime: DateTime(2026, 1, 1, 8, 0),
      );
      final scheduleTimes = [
        buildScheduleTime(id: 1, medicationId: med.id, hour: 8, minute: 0),
        buildScheduleTime(id: 2, medicationId: med.id, hour: 14, minute: 0),
        buildScheduleTime(id: 3, medicationId: med.id, hour: 22, minute: 0),
      ];
      final times = DashboardLogic.getExpectedDoseTimesToday(med, scheduleTimes, now);
      expect(
        times,
        unorderedEquals([
          DateTime(2026, 3, 10, 8, 0),
          DateTime(2026, 3, 10, 14, 0),
          DateTime(2026, 3, 10, 22, 0),
        ]),
      );
    });

    // --- FIXED BUG #1 (KNOWN_ISSUES.md): custom now returns the configured
    // time only on days that are actually configured, read from
    // ScheduleTimes.daysOfWeek.
    test('custom schedule returns the configured time when today is a configured day', () {
      final now = DateTime(2026, 3, 10, 15, 0); // a Tuesday
      expect(now.weekday, DateTime.tuesday);
      final med = buildMedication(
        id: 1,
        scheduleType: 'custom',
        startDateTime: DateTime(2026, 3, 1, 9, 0),
      );
      final scheduleTimes = [
        buildScheduleTime(
          medicationId: med.id,
          hour: 9,
          minute: 0,
          daysOfWeek: 'MON,TUE,FRI',
        ),
      ];
      final times = DashboardLogic.getExpectedDoseTimesToday(med, scheduleTimes, now);
      expect(times, [DateTime(2026, 3, 10, 9, 0)]);
    });

    test('custom schedule returns no dose time when today is not a configured day', () {
      final now = DateTime(2026, 3, 10, 15, 0); // a Tuesday
      expect(now.weekday, DateTime.tuesday);
      final med = buildMedication(
        id: 1,
        scheduleType: 'custom',
        startDateTime: DateTime(2026, 3, 1, 9, 0),
      );
      final scheduleTimes = [
        buildScheduleTime(
          medicationId: med.id,
          hour: 9,
          minute: 0,
          daysOfWeek: 'MON,WED,FRI', // no Tuesday
        ),
      ];
      final times = DashboardLogic.getExpectedDoseTimesToday(med, scheduleTimes, now);
      expect(times, isEmpty);
    });

    // --- FIXED BUG #3 (KNOWN_ISSUES.md): every_x_hours now reads the
    // medication's real configured interval instead of a hardcoded 4.
    test(
      "every_x_hours uses the medication's real configured interval, not a hardcoded value",
      () {
        final now = DateTime(2026, 3, 10, 15, 0);
        final med = buildMedication(
          id: 1,
          scheduleType: 'every_x_hours',
          startDateTime: DateTime(2026, 3, 10, 7, 0),
        );
        final scheduleTimes = [
          buildScheduleTime(medicationId: med.id, hour: 7, minute: 0, intervalHours: 6),
        ];
        final times = DashboardLogic.getExpectedDoseTimesToday(med, scheduleTimes, now);
        expect(times, isNotEmpty);
        expect(
          times,
          contains(DateTime(2026, 3, 10, 7, 0)),
          reason: 'the configured time itself should be on the grid',
        );
        for (var i = 1; i < times.length; i++) {
          expect(
            times[i].difference(times[i - 1]).inHours,
            6,
            reason: 'consecutive dose times should be exactly the configured '
                '6-hour interval apart, not the previously-hardcoded 4 hours',
          );
        }
      },
    );

    test('returns no dose times when the medication has no ScheduleTimes rows at all', () {
      final now = DateTime(2026, 3, 10, 15, 0);
      final med = buildMedication(
        id: 1,
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 1, 1, 8, 0),
      );
      final times = DashboardLogic.getExpectedDoseTimesToday(med, const [], now);
      expect(times, isEmpty);
    });
  });

  group('computeTimeDots', () {
    test('a confirmed dose is marked taken', () {
      final now = DateTime(2026, 3, 10, 8, 5);
      final med = buildMedication(
        id: 1,
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final scheduleTimes = {
        med.id: [buildScheduleTime(medicationId: med.id, hour: 8, minute: 0)],
      };
      final dose = buildDoseEvent(
        medicationId: med.id,
        scheduledTime: DateTime(2026, 3, 10, 8, 0),
        status: 'taken',
      );
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: [dose],
        now: now,
        scheduleTimesByMedicationId: scheduleTimes,
      );
      expect(dots['8:00 AM'], 'taken');
    });

    test('a pending dose still within its window is marked pending', () {
      final now = DateTime(2026, 3, 10, 8, 30); // 30 min after, window=30
      final med = buildMedication(
        id: 1,
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final scheduleTimes = {
        med.id: [buildScheduleTime(medicationId: med.id, hour: 8, minute: 0)],
      };
      final dose = buildDoseEvent(
        medicationId: med.id,
        scheduledTime: DateTime(2026, 3, 10, 8, 0),
        status: 'pending',
      );
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: [dose],
        now: now,
        scheduleTimesByMedicationId: scheduleTimes,
      );
      expect(dots['8:00 AM'], 'pending');
    });

    test('a pending dose past its window is marked missed', () {
      final now = DateTime(2026, 3, 10, 10, 30); // 150 min after, window=30
      final med = buildMedication(
        id: 1,
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final scheduleTimes = {
        med.id: [buildScheduleTime(medicationId: med.id, hour: 8, minute: 0)],
      };
      final dose = buildDoseEvent(
        medicationId: med.id,
        scheduledTime: DateTime(2026, 3, 10, 8, 0),
        status: 'pending',
      );
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: [dose],
        now: now,
        scheduleTimesByMedicationId: scheduleTimes,
      );
      expect(dots['8:00 AM'], 'missed');
    });

    test('an expected time with no matching dose event produces no dot', () {
      final now = DateTime(2026, 3, 10, 8, 30);
      final med = buildMedication(
        id: 1,
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final scheduleTimes = {
        med.id: [buildScheduleTime(medicationId: med.id, hour: 8, minute: 0)],
      };
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: const [],
        now: now,
        scheduleTimesByMedicationId: scheduleTimes,
      );
      expect(dots, isEmpty);
    });

    // --- FIXED BUG #2 (KNOWN_ISSUES.md): "cross-medication window bug".
    // computeTimeDots used to be called with a single, shared
    // schedType/intervalH (from whichever medication owned "next dose") and
    // applied that SAME window to every medication's dots. Each dot is now
    // resolved from its OWN medication's ScheduleTimes.
    test(
      "each dot uses its OWN medication's window size, independent of other medications",
      () {
        // medA -- once_daily, 30-minute window.
        final medA = buildMedication(
          id: 1,
          scheduleType: 'once_daily',
          startDateTime: DateTime(2026, 3, 10, 7, 0),
        );
        // medB -- its own, much tighter window: every_x_hours with a
        // 1-hour interval -> min(30, 1*5) = 5 minutes.
        final medB = buildMedication(
          id: 2,
          scheduleType: 'every_x_hours',
          startDateTime: DateTime(2026, 3, 10, 9, 0),
        );

        final scheduleTimes = {
          medA.id: [buildScheduleTime(medicationId: medA.id, hour: 7, minute: 0)],
          medB.id: [
            buildScheduleTime(medicationId: medB.id, hour: 9, minute: 0, intervalHours: 1),
          ],
        };

        // medB's dose is 20 minutes late: past its OWN 5-minute window, but
        // would still be inside medA's 30-minute window if the bug were
        // still present.
        final medBDose = buildDoseEvent(
          id: 10,
          medicationId: medB.id,
          scheduledTime: DateTime(2026, 3, 10, 9, 0),
          status: 'pending',
        );
        final now = DateTime(2026, 3, 10, 9, 20);

        final dots = DashboardLogic.computeTimeDots(
          meds: [medA, medB],
          doses: [medBDose],
          now: now,
          scheduleTimesByMedicationId: scheduleTimes,
        );

        final medBDotKey = DashboardLogic.formatTime(medBDose.scheduledTime);
        expect(
          dots[medBDotKey],
          'missed',
          reason: "medB's dose is 20 minutes late, past its own 5-minute "
              "window -- confirms it's judged using its own schedule, not "
              "medA's.",
        );
      },
    );

    test(
      'every_x_hours medications are judged against their OWN configured interval',
      () {
        final now = DateTime(2026, 3, 10, 8, 50); // 50 min after the dose

        final med = buildMedication(
          id: 1,
          scheduleType: 'every_x_hours',
          startDateTime: DateTime(2026, 3, 10, 8, 0),
        );
        // window = min(30, 2*5) = 10 minutes; 50 minutes late is past it.
        final scheduleTimes = {
          med.id: [
            buildScheduleTime(medicationId: med.id, hour: 8, minute: 0, intervalHours: 2),
          ],
        };
        final dose = buildDoseEvent(
          medicationId: med.id,
          scheduledTime: DateTime(2026, 3, 10, 8, 0),
          status: 'pending',
        );

        final dots = DashboardLogic.computeTimeDots(
          meds: [med],
          doses: [dose],
          now: now,
          scheduleTimesByMedicationId: scheduleTimes,
        );

        expect(dots['8:00 AM'], 'missed');
      },
    );
  });
}
