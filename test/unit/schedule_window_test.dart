// Unit tests for the shared dose-timing math in schedule_window.dart:
// scheduleCycleMinutes (the gap between one dose and the next),
// scheduleWindowMinutes (the on-time window derived from that gap), and
// scheduleReminderMinutesBefore (the "coming up" reminder offset, always
// inside the window).
import 'package:flutter_test/flutter_test.dart';
import 'package:medication_tracker/shared/schedule_window.dart';

void main() {
  group('scheduleCycleMinutes', () {
    test('once_daily is always 24 hours', () {
      expect(scheduleCycleMinutes('once_daily', 0), 24 * 60);
    });

    test('custom is always 24 hours', () {
      expect(scheduleCycleMinutes('custom', 0), 24 * 60);
    });

    test('every_x_hours is the configured interval in minutes', () {
      expect(scheduleCycleMinutes('every_x_hours', 6), 6 * 60);
      expect(scheduleCycleMinutes('every_x_hours', 1), 60);
    });

    test('every_x_hours falls back to 24 hours if the interval is 0/unset', () {
      expect(scheduleCycleMinutes('every_x_hours', 0), 24 * 60);
    });

    test('multiple_times uses the smallest gap between configured times', () {
      // 8:00, 14:00, 22:00 -> gaps of 6h, 8h, and (22:00 to next day's 8:00) 10h.
      final minutesOfDay = [8 * 60, 14 * 60, 22 * 60];
      expect(scheduleCycleMinutes('multiple_times', 0, minutesOfDay), 6 * 60);
    });

    test('multiple_times wraps past midnight when finding the smallest gap', () {
      // 6:00 and 23:00 -> same-day gap is 17h, but wrapping (23:00 to next
      // day's 6:00) is only 7h, which is smaller.
      final minutesOfDay = [6 * 60, 23 * 60];
      expect(scheduleCycleMinutes('multiple_times', 0, minutesOfDay), 7 * 60);
    });

    test('multiple_times falls back to 24 hours with fewer than 2 times', () {
      expect(scheduleCycleMinutes('multiple_times', 0, [8 * 60]), 24 * 60);
      expect(scheduleCycleMinutes('multiple_times', 0, []), 24 * 60);
    });
  });

  group('scheduleWindowMinutes', () {
    test('is capped at 30 minutes for loosely-spaced schedules', () {
      expect(scheduleWindowMinutes('once_daily', 0), 30);
      expect(scheduleWindowMinutes('every_x_hours', 24), 30);
      expect(scheduleWindowMinutes('every_x_hours', 6), 30); // 6*60/12 = 30, at the cap
    });

    test('shrinks proportionally for tightly-spaced schedules', () {
      expect(scheduleWindowMinutes('every_x_hours', 4), 20);
      expect(scheduleWindowMinutes('every_x_hours', 2), 10);
      expect(scheduleWindowMinutes('every_x_hours', 1), 5);
    });

    test('multiple_times derives its window from the smallest configured gap', () {
      // Smallest gap 4h (240 min) -> 240/12 = 20 minutes.
      final minutesOfDay = [8 * 60, 12 * 60, 20 * 60];
      expect(scheduleWindowMinutes('multiple_times', 0, minutesOfDay), 20);
    });
  });

  group('scheduleReminderMinutesBefore', () {
    test('is capped at 10 minutes for a 30-minute (or larger) window', () {
      expect(scheduleReminderMinutesBefore(30), 10);
      expect(scheduleReminderMinutesBefore(60), 10);
    });

    test('shrinks proportionally, and always stays inside the window', () {
      expect(scheduleReminderMinutesBefore(20), 6);
      expect(scheduleReminderMinutesBefore(10), 3);
      expect(scheduleReminderMinutesBefore(5), 1);
    });
  });
}
