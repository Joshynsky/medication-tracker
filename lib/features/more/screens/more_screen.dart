import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'developer_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

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
          _MenuTile(icon: Icons.notifications_outlined, title: 'Notification Settings', subtitle: 'Customize reminder behavior', onTap: () {}),
          _MenuTile(icon: Icons.people_outlined, title: 'Caregiver Mode', subtitle: 'Switch to managing patients', onTap: () {}),
          _MenuTile(icon: Icons.backup_outlined, title: 'Backup & Sync', subtitle: 'Cloud sync via Supabase', onTap: () {}),
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
  final VoidCallback onTap;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
