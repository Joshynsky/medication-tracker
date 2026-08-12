// Unit tests for the dashboard's window/dose-status logic, extracted from
// `_DashboardScreenState` into lib/features/dashboard/dashboard_logic.dart
// specifically so it could be tested here without pumping widgets.
//
// Some tests below are EXPECTED TO FAIL. They document known bugs found
// during a code-review conversation ("Build out a real test suite for
// MediTrack", 2026-08-11) and intentionally assert the CORRECT/fixed
// behavior rather than the current buggy behavior. Do not "fix" the
// assertions to make them pass -- the failures are the point.
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/features/dashboard/dashboard_logic.dart';

import 'fixtures.dart';

void main() {
  group('windowMinutes', () {
    test('once_daily is always 120 minutes regardless of intervalHours', () {
      expect(DashboardLogic.windowMinutes('once_daily', 6), 120);
      expect(DashboardLogic.windowMinutes('once_daily', 999), 120);
    });

    test('every_x_hours scales with the interval: (intervalHours * 60) ~/ 5', () {
      expect(DashboardLogic.windowMinutes('every_x_hours', 4), 48);
      expect(DashboardLogic.windowMinutes('every_x_hours', 6), 72);
      expect(DashboardLogic.windowMinutes('every_x_hours', 2), 24);
    });

    test('other schedule types (multiple_times, custom, unknown) default to 60 minutes', () {
      expect(DashboardLogic.windowMinutes('multiple_times', 6), 60);
      expect(DashboardLogic.windowMinutes('custom', 6), 60);
      expect(DashboardLogic.windowMinutes('anything_else', 6), 60);
    });
  });

  group('isInWindow', () {
    test('true when now is before the scheduled time but within the window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 8, 0); // 60 min before, window=120
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isTrue);
    });

    test('true when now is after the scheduled time but within the window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 9, 30); // 30 min after, window=120
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isTrue);
    });

    test('false when outside the window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 12, 0); // 180 min after, window=120
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isFalse);
    });

    test('boundary: exactly at the window edge counts as in-window', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 11, 0); // exactly 120 min, window=120
      expect(DashboardLogic.isInWindow(now, scheduled, 'once_daily', 0), isTrue);
    });
  });

  group('isPastWindow', () {
    test('false before the window closes', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 10, 30); // 90 min after, window=120
      expect(DashboardLogic.isPastWindow(now, scheduled, 'once_daily', 0), isFalse);
    });

    test('true once the window has closed', () {
      final scheduled = DateTime(2026, 3, 10, 9, 0);
      final now = DateTime(2026, 3, 10, 11, 30); // 150 min after, window=120
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

  group('getExpectedDoseTimesToday', () {
    test('once_daily returns exactly one time today, at the configured hour/minute', () {
      final now = DateTime(2026, 3, 10, 15, 0);
      final med = buildMedication(
        scheduleType: 'once_daily',
        startDateTime: DateTime(2025, 1, 1, 8, 30),
      );
      final times = DashboardLogic.getExpectedDoseTimesToday(med, now);
      expect(times, [DateTime(2026, 3, 10, 8, 30)]);
    });

    test('every_x_hours returns multiple times spread across today', () {
      final now = DateTime(2026, 3, 10, 15, 0);
      final med = buildMedication(
        scheduleType: 'every_x_hours',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final times = DashboardLogic.getExpectedDoseTimesToday(med, now);
      expect(times.length, greaterThan(1));
    });

    // --- KNOWN BUG (documented in "Build out a real test suite for
    // MediTrack" conversation, 2026-08-11): getExpectedDoseTimesToday only
    // implements 'once_daily' and 'every_x_hours'. 'multiple_times' falls
    // through to the default branch, which returns a single time
    // (med.startDateTime's hour/minute) regardless of how many times a day
    // the medication is actually configured for. A medication taken 3x/day
    // currently only ever produces ONE dashboard time-dot instead of three.
    // This test intentionally asserts the CORRECT behavior and is expected
    // to FAIL until the bug is fixed.
    test(
      'BUG: multiple_times schedule should return more than one dose time today '
      '(currently always returns exactly one -- known bug, not fixed here)',
      () {
        final now = DateTime(2026, 3, 10, 15, 0);
        // Conceptually configured for three times/day (e.g. 8:00, 14:00,
        // 22:00 -- stored as separate ScheduleTimes rows in the real app),
        // but the function only ever receives the Medication row, which
        // carries a single startDateTime.
        final med = buildMedication(
          scheduleType: 'multiple_times',
          startDateTime: DateTime(2026, 3, 10, 8, 0),
        );
        final times = DashboardLogic.getExpectedDoseTimesToday(med, now);
        expect(
          times.length,
          greaterThan(1),
          reason: 'a multiple_times schedule should produce more than one '
              'dose time per day; getExpectedDoseTimesToday(Medication) only '
              'ever reads med.startDateTime and has no access to the '
              "medication's other configured times, so it always returns "
              'exactly one.',
        );
      },
    );

    // --- KNOWN BUG (same conversation as above): 'custom' schedules
    // (specific weekdays) also fall through to the default branch, so the
    // function returns a dose time for TODAY even when today isn't one of
    // the medication's configured days. The Medication row doesn't carry
    // customDays at all (that lives on ScheduleTimes.daysOfWeek), so the
    // function has no way to filter by day of week.
    // This test intentionally asserts the CORRECT behavior and is expected
    // to FAIL until the bug is fixed.
    test(
      'BUG: custom schedule should return no dose time today when today is not '
      'a configured day (currently ignores day-of-week entirely -- known bug, not fixed here)',
      () {
        final now = DateTime(2026, 3, 10, 15, 0); // a Tuesday
        expect(now.weekday, DateTime.tuesday);
        // Conceptually configured for Mon/Wed/Fri only -- today (Tuesday)
        // should NOT produce a dose time. The function has no way to know
        // this, since customDays isn't part of Medication at all.
        final med = buildMedication(
          scheduleType: 'custom',
          startDateTime: DateTime(2026, 3, 1, 9, 0),
        );
        final times = DashboardLogic.getExpectedDoseTimesToday(med, now);
        expect(
          times,
          isEmpty,
          reason: "today is not one of the medication's configured custom "
              'days, so no dose time should be expected today; '
              'getExpectedDoseTimesToday ignores day-of-week filtering '
              'entirely and always returns one time for custom schedules.',
        );
      },
    );
  });

  group('computeTimeDots', () {
    test('a confirmed dose is marked taken', () {
      final now = DateTime(2026, 3, 10, 8, 5);
      final med = buildMedication(
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final dose = buildDoseEvent(
        medicationId: med.id,
        scheduledTime: DateTime(2026, 3, 10, 8, 0),
        status: 'taken',
      );
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: [dose],
        now: now,
        schedType: 'once_daily',
        intervalH: 12,
      );
      expect(dots['8:00 AM'], 'taken');
    });

    test('a pending dose still within its window is marked pending', () {
      final now = DateTime(2026, 3, 10, 8, 30); // 30 min after, window=120
      final med = buildMedication(
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final dose = buildDoseEvent(
        medicationId: med.id,
        scheduledTime: DateTime(2026, 3, 10, 8, 0),
        status: 'pending',
      );
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: [dose],
        now: now,
        schedType: 'once_daily',
        intervalH: 12,
      );
      expect(dots['8:00 AM'], 'pending');
    });

    test('a pending dose past its window is marked missed', () {
      final now = DateTime(2026, 3, 10, 10, 30); // 150 min after, window=120
      final med = buildMedication(
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final dose = buildDoseEvent(
        medicationId: med.id,
        scheduledTime: DateTime(2026, 3, 10, 8, 0),
        status: 'pending',
      );
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: [dose],
        now: now,
        schedType: 'once_daily',
        intervalH: 12,
      );
      expect(dots['8:00 AM'], 'missed');
    });

    test('an expected time with no matching dose event produces no dot', () {
      final now = DateTime(2026, 3, 10, 8, 30);
      final med = buildMedication(
        scheduleType: 'once_daily',
        startDateTime: DateTime(2026, 3, 10, 8, 0),
      );
      final dots = DashboardLogic.computeTimeDots(
        meds: [med],
        doses: const [],
        now: now,
        schedType: 'once_daily',
        intervalH: 12,
      );
      expect(dots, isEmpty);
    });

    // --- KNOWN BUG: "cross-medication window bug" (documented in "Build out
    // a real test suite for MediTrack" conversation, 2026-08-11).
    // computeTimeDots is called with a single, shared schedType/intervalH
    // (computed once by the dashboard from whichever medication owns "next
    // dose") and applies that SAME window to every medication's dots,
    // instead of each medication using its own schedule type's window.
    // This test intentionally asserts the CORRECT behavior (each dot uses
    // its own medication's window) and is expected to FAIL until the bug
    // is fixed.
    test(
      "BUG: each dot should use its OWN medication's window size, not a "
      'shared window from whichever medication owns "next dose" '
      '(currently uses one shared window for all -- known bug, not fixed here)',
      () {
        final now = DateTime(2026, 3, 10, 10, 30);

        // medA owns "next dose" in this scenario -- once_daily, 120-minute
        // window. This is what the dashboard would compute as the single
        // shared schedType/intervalH for the whole loop.
        final medA = buildMedication(
          id: 1,
          scheduleType: 'once_daily',
          startDateTime: DateTime(2026, 3, 10, 7, 0),
        );

        // medB has its own, much tighter window: 'multiple_times' falls
        // into the default branch of windowMinutes -> 60 minutes.
        final medB = buildMedication(
          id: 2,
          scheduleType: 'multiple_times',
          startDateTime: DateTime(2026, 3, 10, 9, 0),
        );

        // medB's dose is 90 minutes late: past its OWN 60-minute window,
        // but still inside medA's 120-minute window.
        final medBDose = buildDoseEvent(
          id: 10,
          medicationId: medB.id,
          scheduledTime: DateTime(2026, 3, 10, 9, 0),
          status: 'pending',
        );

        final dots = DashboardLogic.computeTimeDots(
          meds: [medA, medB],
          doses: [medBDose],
          now: now,
          schedType: medA.scheduleType, // the shared/buggy value
          intervalH: 12,
        );

        final medBDotKey = DashboardLogic.formatTime(medBDose.scheduledTime);
        expect(
          dots[medBDotKey],
          'missed',
          reason: "medB's dose is 90 minutes late, past its own 60-minute "
              '(multiple_times/default) window, so it should show as missed. '
              "But computeTimeDots checks it against medA's shared "
              "120-minute (once_daily) window instead of medB's own, so it "
              'currently stays "pending".',
        );
      },
    );
  });
}
