import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../services/notification_service.dart';
import '../../../data/repositories/medication_repository.dart';

class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Notifications', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _TestButton(
            icon: Icons.notifications_active,
            title: 'Send Test Notification (Now)',
            subtitle: 'Fires immediately',
            onTap: () async {
              await NotificationService.showDoseReminder(
                id: DateTime.now().millisecondsSinceEpoch % 100000,
                title: '💊 Test Notification',
                body: 'This is a test notification from MediTrack',
                medicationId: 0,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification sent! Check your notification bar.')),
              );
            },
          ),
          _TestButton(
            icon: Icons.timer,
            title: 'Send Test Notification (10 sec)',
            subtitle: 'Fires in 10 seconds (leave the app to see it)',
            onTap: () {
              final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
              final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

              FlutterLocalNotificationsPlugin().zonedSchedule(
                9999,
                '⏰ Scheduled Test',
                'This notification was scheduled 10 seconds ago',
                tzTime,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'dose_reminders',
                    'Dose Reminders',
                    channelDescription: 'Test',
                    importance: Importance.max,
                    priority: Priority.high,
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification scheduled! Close the app and wait 10 seconds.')),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Database', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _TestButton(
            icon: Icons.storage,
            title: 'Show Database Stats',
            subtitle: 'Medication and dose counts',
            onTap: () async {
              final repo = ref.read(medicationRepositoryProvider);
              final patientId = await repo.ensureDefaultUserAndPatient();
              final meds = await repo.getMedications(patientId);
              final doses = await repo.getTodaysDoses(patientId);

              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Database Stats'),
                  content: Text(
                    'Active Medications: ${meds.length}\n'
                    'Today\'s Doses: ${doses.length}\n'
                    'Taken: ${doses.where((d) => d.status == 'taken').length}\n'
                    'Pending: ${doses.where((d) => d.status == 'pending').length}\n'
                    'Missed: ${doses.where((d) => d.status == 'missed').length}',
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Danger Zone', style: theme.textTheme.titleMedium?.copyWith(color: Colors.red)),
          const SizedBox(height: 8),
          _TestButton(
            icon: Icons.science,
            title: "Create Test Medication",
            subtitle: "Adds a 21-pill medication starting April 3, 15 taken already",
            onTap: () async {
              final repo = ref.read(medicationRepositoryProvider);
              final patientId = await repo.ensureDefaultUserAndPatient();
              
              final startDate = DateTime(2026, 4, 3, 8, 0);
              final medId = await repo.saveMedication(
                patientId: patientId,
                name: "Test Medicine",
                dosage: "500mg",
                scheduleType: "once_daily",
                startDateTime: startDate,
                totalPills: 21,
                notes: "Test medication for debugging",
                times: [{"hour": 8, "minute": 0}],
                intervalHours: 24,
                customDays: {},
              );
              
              // Manually mark 15 doses as taken (April 3-17)
              final allDoses = await repo.getDoseHistory(medId);
              allDoses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
              for (int i = 0; i < 15 && i < allDoses.length; i++) {
                await repo.confirmDose(allDoses[i].id, medId);
              }
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Test medication created! 15 of 21 pills taken.")),
              );
            },
          ),
          _TestButton(
            icon: Icons.delete_forever,
            title: 'Reset All Data',
            subtitle: 'Delete all medications and doses',
            isDestructive: true,
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset All Data?'),
                  content: const Text('This will permanently delete all medications and dose history.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        // TODO: Add reset functionality
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reset not implemented yet')),
                        );
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _TestButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : theme.colorScheme.primary),
        title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : null)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
