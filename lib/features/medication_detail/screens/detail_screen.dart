import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../data/local/database.dart';
import '../../../providers/dashboard_provider.dart';

class MedicationDetailScreen extends ConsumerWidget {
  final Medication medication;

  const MedicationDetailScreen({super.key, required this.medication});

  void _deleteMedication(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to delete ${medication.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ref.read(dashboardProvider.notifier).deleteMedication(medication.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${medication.name} deleted'), behavior: SnackBarBehavior.floating),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _scheduleTypeText(String type) {
    switch (type) {
      case 'once_daily': return 'Once daily';
      case 'multiple_times': return 'Multiple specific times';
      case 'every_x_hours': return 'Every X hours';
      case 'custom': return 'Custom schedule';
      default: return type;
    }
  }

  String _dosageDisplay(Medication med) {
    final parts = <String>[];
    if (med.strengthValue != null && med.strengthUnit != null && med.strengthValue! > 0) {
      parts.add('${med.strengthValue!.toInt()}${med.strengthUnit}');
    }
    if (med.amountPerDose != null && med.amountUnit != null && med.amountPerDose! > 0) {
      parts.add('Take ${med.amountPerDose!.toInt()} ${med.amountUnit}');
    }
    return parts.isEmpty ? med.dosage : parts.join(' · ');
  }

  String _quantityText(Medication med) {
    if (med.totalPills <= 0) return 'Not set';
    final unit = med.quantityUnit ?? 'units';
    return '${med.totalPills} $unit';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pillsTaken = medication.totalPills - medication.pillsRemaining;
    final adherencePercent = medication.totalPills > 0 ? (pillsTaken / medication.totalPills * 100) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(medication.name),
        centerTitle: true,
        actions: [
          PopupMenuButton(
            onSelected: (value) { if (value == 'delete') _deleteMedication(context, ref); },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.primaryContainer)),
            child: Column(children: [
              Row(children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.medication, size: 28, color: theme.colorScheme.primary)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(medication.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_dosageDisplay(medication), style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: medication.isActive ? Colors.green.withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)), child: Text(medication.isActive ? 'Active' : 'Inactive', style: theme.textTheme.labelSmall?.copyWith(color: medication.isActive ? Colors.green : theme.colorScheme.onSurfaceVariant))),
              ]),
              if (medication.totalPills > 0) ...[
                const SizedBox(height: 20), const Divider(), const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${adherencePercent.toStringAsFixed(0)}% complete', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${medication.pillsRemaining} ${medication.quantityUnit ?? 'units'} remaining', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ])),
                  const SizedBox(width: 16),
                  SizedBox(width: 48, height: 48, child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(value: adherencePercent / 100, strokeWidth: 4, backgroundColor: theme.colorScheme.surfaceContainerHighest, valueColor: AlwaysStoppedAnimation<Color>(adherencePercent >= 80 ? Colors.green : theme.colorScheme.primary)),
                    Text('${adherencePercent.toStringAsFixed(0)}%', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ])),
                ]),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: adherencePercent / 100, minHeight: 6, backgroundColor: theme.colorScheme.surfaceContainerHighest, valueColor: AlwaysStoppedAnimation<Color>(adherencePercent >= 80 ? Colors.green : theme.colorScheme.primary))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$pillsTaken of ${medication.totalPills} ${medication.quantityUnit ?? 'units'} taken', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]),
              ],
            ]),
          ),
          const SizedBox(height: 24),
          Text('Schedule', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _InfoRow(icon: Icons.repeat, label: 'Type', value: _scheduleTypeText(medication.scheduleType)),
              const Divider(height: 24),
              _InfoRow(icon: Icons.inventory_2, label: 'Quantity', value: _quantityText(medication)),
              const Divider(height: 24),
              _InfoRow(icon: Icons.checklist, label: 'Taken', value: '$pillsTaken ${medication.quantityUnit ?? 'units'}'),
              const Divider(height: 24),
              _InfoRow(icon: Icons.medication, label: 'Dosage', value: _dosageDisplay(medication)),
              const Divider(height: 24),
              _InfoRow(icon: Icons.category, label: 'Form', value: medication.form ?? 'Not specified'),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deleteMedication(context, ref),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Delete Medication', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 12),
      SizedBox(width: 70, child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
      Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
    ]);
  }
}
