import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/alarm_service.dart';
import '../../../services/notification_service.dart';
import 'developer_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  /// Lets the user (re-)trigger all reminder-related permission requests --
  /// useful if they declined during onboarding and want to enable reminders
  /// later. No dedicated settings screen; this just re-runs the same
  /// requests onboarding does and reports what happened.
  Future<void> _requestNotificationPermissions(BuildContext context) async {
    final notificationsGranted = await NotificationService.requestPermission();
    final exactAlarmsGranted = await AlarmService.requestExactAlarmPermission();
    final batteryExemptionGranted =
        await AlarmService.requestBatteryOptimizationExemption();

    if (!context.mounted) return;
    final allGranted =
        notificationsGranted && exactAlarmsGranted && batteryExemptionGranted;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allGranted
              ? 'Notifications, exact alarms, and battery restrictions are enabled.'
              : 'Some permissions were not granted. You can enable them from '
                  "your device's Settings app under MediTrack. On some "
                  'phones (e.g. Xiaomi/MIUI), also check "Autostart" under '
                  'app permissions -- Android has no in-app way to request '
                  'that one.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('More'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              CircleAvatar(radius: 28, backgroundColor: theme.colorScheme.primaryContainer, child: Icon(Icons.person, size: 28, color: theme.colorScheme.primary)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Medications', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('Personal Account', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ])),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ]),
          ),
          const SizedBox(height: 24),
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            subtitle: 'Enable reminders & exact alarms',
            onTap: () => _requestNotificationPermissions(context),
          ),
          _MenuTile(icon: Icons.people_outlined, title: 'Caregiver Mode', subtitle: 'Switch to managing patients', onTap: () {}),
          _MenuTile(icon: Icons.backup_outlined, title: 'Backup & Sync', subtitle: 'Coming soon', onTap: null),
          _MenuTile(icon: Icons.developer_mode, title: 'Developer Tools', subtitle: 'Testing and debugging', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperScreen()))),
          _MenuTile(icon: Icons.info_outlined, title: 'About MediTrack', subtitle: 'Version 1.0.0', onTap: () {}),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        onTap: onTap,
        enabled: onTap != null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
