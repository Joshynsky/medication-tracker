import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_medication_provider.dart';

class StepPreview extends ConsumerWidget {
  const StepPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(medicationNameProvider);
    final dosage = ref.watch(dosageProvider);
    final scheduleType = ref.watch(scheduleTypeProvider);
    final times = ref.watch(scheduleTimesProvider);
    final intervalHours = ref.watch(intervalHoursProvider);
    final customDays = ref.watch(customDaysProvider);
    final startDate = ref.watch(startDateProvider);
    final pillCount = ref.watch(pillCountProvider);
    final notes = ref.watch(notesProvider);
    final outerPhoto = ref.watch(photoOuterProvider);
    final pillsPhoto = ref.watch(photoPillsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Here\'s your plan',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review everything before saving.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Medication card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primaryContainer,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name & Dosage
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Unnamed medication' : name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (dosage.isNotEmpty)
                            Text(
                              dosage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // Schedule
                _PreviewRow(
                  icon: Icons.schedule,
                  label: 'Schedule',
                  value: _buildScheduleText(
                    scheduleType,
                    times,
                    intervalHours,
                    customDays,
                  ),
                ),
                const SizedBox(height: 12),

                // Start date
                _PreviewRow(
                  icon: Icons.calendar_today,
                  label: 'Starts',
                  value: '${startDate.day}/${startDate.month}/${startDate.year} at ${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 12),

                // Pill count
                if (pillCount.isNotEmpty) ...[
                  _PreviewRow(
                    icon: Icons.inventory_2,
                    label: 'Quantity',
                    value: '$pillCount pills',
                  ),
                  const SizedBox(height: 12),
                  _PreviewRow(
                    icon: Icons.flag,
                    label: 'Ends',
                    value: _calculateEndDate(startDate, pillCount, scheduleType, times, intervalHours),
                  ),
                  const SizedBox(height: 12),
                ],

                // Notes
                if (notes.isNotEmpty) ...[
                  _PreviewRow(
                    icon: Icons.note_alt,
                    label: 'Notes',
                    value: notes,
                  ),
                  const SizedBox(height: 12),
                ],

                // Photos
                if (outerPhoto.isNotEmpty || pillsPhoto.isNotEmpty) ...[
                  _PreviewRow(
                    icon: Icons.photo_camera,
                    label: 'Photos',
                    value: '${outerPhoto.isNotEmpty ? '✓ ' : ''}Packaging${pillsPhoto.isNotEmpty ? '  ✓ Pills' : ''}',
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What happens next
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'We\'ll remind you when it\'s time to take your medication.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _buildScheduleText(
    String scheduleType,
    List<Map<String, int>> times,
    int intervalHours,
    Set<String> customDays,
  ) {
    switch (scheduleType) {
      case 'once_daily':
        final t = times.first;
        return 'Once daily at ${t['hour'].toString().padLeft(2, '0')}:${t['minute'].toString().padLeft(2, '0')}';
      case 'multiple_times':
        return times.map((t) =>
          '${t['hour'].toString().padLeft(2, '0')}:${t['minute'].toString().padLeft(2, '0')}'
        ).join(', ');
      case 'every_x_hours':
        return 'Every $intervalHours hours';
      case 'custom':
        final days = customDays.join(', ');
        final t = times.first;
        return '$days at ${t['hour'].toString().padLeft(2, '0')}:${t['minute'].toString().padLeft(2, '0')}';
      default:
        return scheduleType;
    }
  }

  String _calculateEndDate(
    DateTime startDate,
    String pillCount,
    String scheduleType,
    List<Map<String, int>> times,
    int intervalHours,
  ) {
    final count = int.tryParse(pillCount);
    if (count == null) return 'Unknown';

    int dosesPerDay;
    switch (scheduleType) {
      case 'once_daily':
        dosesPerDay = 1;
        break;
      case 'multiple_times':
        dosesPerDay = times.length;
        break;
      case 'every_x_hours':
        dosesPerDay = (24 / intervalHours).ceil();
        break;
      case 'custom':
        dosesPerDay = 1; // Simplified
        break;
      default:
        dosesPerDay = 1;
    }

    final days = (count / dosesPerDay).ceil();
    final endDate = startDate.add(Duration(days: days));
    return '${endDate.day}/${endDate.month}/${endDate.year} ($days days)';
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}