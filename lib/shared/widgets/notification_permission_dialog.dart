import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/medication_repository.dart';
import '../../services/alarm_service.dart';
import '../../services/notification_service.dart';

/// The one-time "why we need notification permission" moment. Shown right
/// after a user saves their first medication -- the point at which a
/// reminder first becomes something concrete to explain, rather than at
/// app launch before there's anything to remind about.
class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  /// Shows the dialog if (and only if) it hasn't been shown before, then
  /// marks it as shown regardless of which button the user taps -- this is
  /// a one-time explanation, not a nag screen. Call after a medication has
  /// been saved successfully.
  static Future<void> showIfNeeded(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(medicationRepositoryProvider);
    // Don't assume the caller already created the user row -- markOnboardingSeen
    // below is a no-op without one, which would silently fail to persist.
    await repository.ensureDefaultUserAndPatient();
    final alreadySeen = await repository.hasSeenOnboarding();
    if (alreadySeen || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NotificationPermissionDialog(),
    );
    await repository.markOnboardingSeen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(
        Icons.notifications_active_outlined,
        color: theme.colorScheme.primary,
        size: 32,
      ),
      title: const Text('Stay on track with reminders'),
      content: const Text(
        "MediTrack can remind you when it's time to take a dose. To do "
        'that, we need permission to send notifications, schedule precise '
        'alarms, and run in the background without being battery-throttled. '
        'You can always change this later from More > Notification '
        'Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () async {
            await NotificationService.requestPermission();
            await AlarmService.requestExactAlarmPermission();
            await AlarmService.requestBatteryOptimizationExemption();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Enable Notifications'),
        ),
      ],
    );
  }
}
