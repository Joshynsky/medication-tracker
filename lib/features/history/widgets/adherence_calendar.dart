import 'package:flutter/material.dart';
import '../providers/history_provider.dart';
import 'full_calendar.dart';

class AdherenceCalendar extends StatelessWidget {
  final List<DayStatus> weekDays;

  const AdherenceCalendar({super.key, required this.weekDays});

  void _openCalendar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FullCalendar(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                onPressed: () => _openCalendar(context),
                icon: Icon(Icons.calendar_month, size: 16, color: theme.colorScheme.primary),
                label: Text('Month', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _openCalendar(context),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final day = weekDays[index];
                final isToday = day.date == DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                );

                Color bgColor;
                String label;

                switch (day.status) {
                  case 'taken':
                    bgColor = Colors.green.withOpacity(0.2);
                    label = '✓';
                    break;
                  case 'missed':
                    bgColor = Colors.red.withOpacity(0.2);
                    label = '✗';
                    break;
                  case 'partial':
                    bgColor = Colors.orange.withOpacity(0.2);
                    label = '◐';
                    break;
                  default:
                    bgColor = Colors.grey.withOpacity(0.1);
                    label = '○';
                }

                return Column(
                  children: [
                    Text(
                      dayNames[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: isToday
                            ? Border.all(color: theme.colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(label, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
