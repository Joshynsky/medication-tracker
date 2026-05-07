import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_medication_provider.dart';

class StepPreview extends ConsumerWidget {
  const StepPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(medicationNameProvider);
    final form = ref.watch(formProvider);
    final strengthValue = ref.watch(strengthValueProvider);
    final strengthUnit = ref.watch(strengthUnitProvider);
    final amountPerDose = ref.watch(amountPerDoseProvider);
    final amountUnit = ref.watch(amountUnitProvider);
    final quantityUnit = ref.watch(quantityUnitProvider);
    final scheduleType = ref.watch(scheduleTypeProvider);
    final times = ref.watch(scheduleTimesProvider);
    final intervalHours = ref.watch(intervalHoursProvider);
    final customDays = ref.watch(customDaysProvider);
    final startDate = ref.watch(startDateProvider);
    final pillCount = ref.watch(pillCountProvider);
    final notes = ref.watch(notesProvider);
    final theme = Theme.of(context);

    String _dosageText() {
      final parts = <String>[];
      if (strengthValue.isNotEmpty && strengthUnit.isNotEmpty) {
        parts.add('$strengthValue$strengthUnit');
      }
      if (amountPerDose.isNotEmpty && amountUnit.isNotEmpty) {
        parts.add('Take ${amountPerDose} ${amountUnit}');
      }
      return parts.join(' · ');
    }

    String _formLabel() {
      switch (form) {
        case 'pills': return '💊 Pills';
        case 'liquid': return '💧 Liquid';
        case 'ointment': return '🧴 Ointment';
        case 'injection': return '💉 Injection';
        case 'drops': return '👁️ Drops';
        case 'patch': return '🩹 Patch';
        default: return '📦 Other';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Here\'s your plan', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Review everything before saving.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.primaryContainer)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.medication, color: theme.colorScheme.primary)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Unnamed medication' : name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (_dosageText().isNotEmpty) Text(_dosageText(), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Text(_formLabel(), style: theme.textTheme.labelSmall)),
              ])),
            ]),
            const SizedBox(height: 20), const Divider(), const SizedBox(height: 20),

            _PreviewRow(icon: Icons.schedule, label: 'Schedule', value: _buildScheduleText(scheduleType, times, intervalHours, customDays)),
            const SizedBox(height: 12),
            _PreviewRow(icon: Icons.calendar_today, label: 'Starts', value: '${startDate.day}/${startDate.month}/${startDate.year} at ${_formatTime(startDate)}'),
            const SizedBox(height: 12),
            if (pillCount.isNotEmpty) ...[
              _PreviewRow(icon: Icons.inventory_2, label: 'Quantity', value: '$pillCount $quantityUnit'),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _PreviewRow(icon: Icons.note_alt, label: 'Notes', value: notes),
            ],
          ]),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.notifications_active_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text('We\'ll remind you when it\'s time to take your medication.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          ]),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  String _formatTime(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final am = d.hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $am';
  }

  String _buildScheduleText(String scheduleType, List<Map<String, int>> times, int intervalHours, Set<String> customDays) {
    switch (scheduleType) {
      case 'once_daily':
        final t = times.first;
        final h = t['hour']! > 12 ? t['hour']! - 12 : (t['hour']! == 0 ? 12 : t['hour']!);
        final am = t['hour']! < 12 ? 'AM' : 'PM';
        return 'Once daily at $h:${t['minute']!.toString().padLeft(2, '0')} $am';
      case 'multiple_times':
        return times.map((t) {
          final h = t['hour']! > 12 ? t['hour']! - 12 : (t['hour']! == 0 ? 12 : t['hour']!);
          final am = t['hour']! < 12 ? 'AM' : 'PM';
          return '$h:${t['minute']!.toString().padLeft(2, '0')} $am';
        }).join(', ');
      case 'every_x_hours':
        return 'Every $intervalHours hours';
      case 'custom':
        return '${customDays.join(', ')} at ${times.first['hour']}:${times.first['minute']!.toString().padLeft(2, '0')}';
      default:
        return scheduleType;
    }
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PreviewRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 12),
      SizedBox(width: 80, child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
      Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
    ]);
  }
}
