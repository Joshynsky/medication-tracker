import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_medication_provider.dart';

class StepTwoSchedule extends ConsumerStatefulWidget {
  const StepTwoSchedule({super.key});

  @override
  ConsumerState<StepTwoSchedule> createState() => _StepTwoScheduleState();
}

class _StepTwoScheduleState extends ConsumerState<StepTwoSchedule> {
  final List<String> _scheduleTypes = [
    'once_daily',
    'multiple_times',
    'every_x_hours',
    'custom',
  ];

  String _getDisplayText(String type) {
    switch (type) {
      case 'once_daily':
        return 'Once daily';
      case 'multiple_times':
        return 'Multiple specific times';
      case 'every_x_hours':
        return 'Every X hours';
      case 'custom':
        return 'Custom days & times';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleType = ref.watch(scheduleTypeProvider);
    final times = ref.watch(scheduleTimesProvider);
    final intervalHours = ref.watch(intervalHoursProvider);
    final startDate = ref.watch(startDateProvider);
    final theme = Theme.of(context);

    return Directionality(textDirection: TextDirection.ltr, child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'When do you take it?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us your schedule so we can remind you on time.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Schedule Type Dropdown
          Text(
            'Schedule type',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: scheduleType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
            items: _scheduleTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getDisplayText(type)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(scheduleTypeProvider.notifier).state = value;
              }
            },
          ),
          const SizedBox(height: 24),

          // Dynamic fields based on schedule type
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildScheduleFields(
              scheduleType,
              times,
              intervalHours,
              theme,
              ref,
            ),
          ),

          const SizedBox(height: 32),

          // Start Date
          Text(
            'Start date & time',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                helpText: 'Select start date',
              );
              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(startDate),
                  helpText: 'Select start time',
                );
                if (time != null) {
                  ref.read(startDateProvider.notifier).state = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${startDate.day}/${startDate.month}/${startDate.year} at ${startDate.hour.toString().padLeft(2, '0')}:${startDate.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
      ));
  }

  Widget _buildScheduleFields(
    String scheduleType,
    List<Map<String, int>> times,
    int intervalHours,
    ThemeData theme,
    WidgetRef ref,
  ) {
    switch (scheduleType) {
      case 'once_daily':
        return _buildTimePicker(
          'Take at',
          times[0]['hour'] ?? 8,
          times[0]['minute'] ?? 0,
          theme,
          (hour, minute) {
            ref.read(scheduleTimesProvider.notifier).state = [
              {'hour': hour, 'minute': minute},
            ];
          },
        );

      case 'multiple_times':
        return Column(
          key: const ValueKey('multiple_times'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...times.asMap().entries.map((entry) {
              final index = entry.key;
              final time = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTimePicker(
                        'Time ${index + 1}',
                        time['hour'] ?? 8,
                        time['minute'] ?? 0,
                        theme,
                        (hour, minute) {
                          final newTimes = List<Map<String, int>>.from(times);
                          newTimes[index] = {'hour': hour, 'minute': minute};
                          ref.read(scheduleTimesProvider.notifier).state =
                              newTimes;
                        },
                      ),
                    ),
                    if (times.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () {
                          final newTimes = List<Map<String, int>>.from(times);
                          newTimes.removeAt(index);
                          ref.read(scheduleTimesProvider.notifier).state =
                              newTimes;
                        },
                      ),
                    ],
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                final newTimes = [
                  ...times,
                  {'hour': 8, 'minute': 0},
                ];
                ref.read(scheduleTimesProvider.notifier).state = newTimes;
              },
              icon: const Icon(Icons.add),
              label: const Text('Add another time'),
            ),
          ],
        );

      case 'every_x_hours':
        return Column(
          key: const ValueKey('every_x_hours'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Take every',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(
                      text: intervalHours.toString(),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'hrs',
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        ref.read(intervalHoursProvider.notifier).state = parsed;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Starting at ${times[0]['hour'].toString().padLeft(2, '0')}:${times[0]['minute'].toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        );

      case 'custom':
        return Column(
          key: const ValueKey('custom'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Days of the week',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((
                day,
              ) {
                final selected = ref.watch(customDaysProvider).contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: selected,
                  onSelected: (isSelected) {
                    final days = Set<String>.from(ref.read(customDaysProvider));
                    if (isSelected) {
                      days.add(day);
                    } else {
                      days.remove(day);
                    }
                    ref.read(customDaysProvider.notifier).state = days;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildTimePicker(
              'Time',
              times[0]['hour'] ?? 8,
              times[0]['minute'] ?? 0,
              theme,
              (hour, minute) {
                ref.read(scheduleTimesProvider.notifier).state = [
                  {'hour': hour, 'minute': minute},
                ];
              },
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimePicker(
    String label,
    int hour,
    int minute,
    ThemeData theme,
    Function(int hour, int minute) onChanged,
  ) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
          helpText: label,
        );
        if (time != null) {
          onChanged(time.hour, time.minute);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              '$label: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      );
  }
}
