import 'package:flutter/material.dart';
import '../providers/history_provider.dart';

class AdherenceCalendar extends StatelessWidget {
  final List<DayStatus> weekDays;

  const AdherenceCalendar({super.key, required this.weekDays});

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
          Text(
            'This Week',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final day = weekDays[index];
              final isToday = day.date == DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );

              Color bgColor;
              IconData icon;
              String label;

              switch (day.status) {
                case 'taken':
                  bgColor = Colors.green.withOpacity(0.2);
                  icon = Icons.check_circle;
                  label = '✓';
                  break;
                case 'missed':
                  bgColor = Colors.red.withOpacity(0.2);
                  icon = Icons.cancel;
                  label = '✗';
                  break;
                case 'partial':
                  bgColor = Colors.orange.withOpacity(0.2);
                  icon = Icons.adjust;
                  label = '◐';
                  break;
                default:
                  bgColor = Colors.grey.withOpacity(0.1);
                  icon = Icons.circle_outlined;
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
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
