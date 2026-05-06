import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/history_provider.dart';

class FullCalendar extends ConsumerStatefulWidget {
  const FullCalendar({super.key});

  @override
  ConsumerState<FullCalendar> createState() => _FullCalendarState();
}

class _FullCalendarState extends ConsumerState<FullCalendar> {
  late DateTime _currentMonth;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(historyProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Month header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                      });
                    },
                  ),
                  Text(
                    '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Day names
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map((d) => SizedBox(
                          width: 36,
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Calendar grid
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (historyState) {
                  final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
                  final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
                  final today = DateTime.now();

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Build calendar grid
                      Wrap(
                        spacing: 4,
                        runSpacing: 8,
                        children: [
                          // Empty cells before first day
                          for (int i = 0; i < firstWeekday; i++)
                            const SizedBox(width: 36, height: 44),

                          // Day cells
                          for (int day = 1; day <= daysInMonth; day++)
                            _DayCell(
                              day: day,
                              date: DateTime(_currentMonth.year, _currentMonth.month, day),
                              status: _getDayStatus(historyState, _currentMonth.year, _currentMonth.month, day),
                              isToday: today.year == _currentMonth.year &&
                                  today.month == _currentMonth.month &&
                                  today.day == day,
                              isSelected: _selectedDay == day,
                              onTap: () => setState(() => _selectedDay = day),
                            ),
                        ],
                      ),

                      // Selected day detail
                      if (_selectedDay != null) ...[
                        const SizedBox(height: 24),
                        _DayDetail(
                          date: DateTime(_currentMonth.year, _currentMonth.month, _selectedDay!),
                          historyState: historyState,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _getDayStatus(HistoryState state, int year, int month, int day) {
    final date = DateTime(year, month, day);
    final weekDay = state.weekDays.where((d) =>
        d.date.year == date.year &&
        d.date.month == date.month &&
        d.date.day == date.day);

    if (weekDay.isNotEmpty) return weekDay.first.status;
    if (date.isAfter(DateTime.now())) return 'no_doses';
    return 'no_doses';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final DateTime date;
  final String status;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.date,
    required this.status,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor;
    Color dotColor;

    switch (status) {
      case 'taken':
        bgColor = Colors.green.withOpacity(0.15);
        dotColor = Colors.green;
        break;
      case 'missed':
        bgColor = Colors.red.withOpacity(0.15);
        dotColor = Colors.red;
        break;
      case 'partial':
        bgColor = Colors.orange.withOpacity(0.15);
        dotColor = Colors.orange;
        break;
      default:
        bgColor = Colors.transparent;
        dotColor = Colors.transparent;
    }

    if (date.isAfter(DateTime.now())) {
      bgColor = Colors.transparent;
      dotColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
            if (dotColor != Colors.transparent)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DateTime date;
  final HistoryState historyState;

  const _DayDetail({required this.date, required this.historyState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday % 7];
    final meds = historyState.pastMedications;

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
            '$dayName, ${date.day} ${_monthName(date.month)}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (meds.isEmpty)
            Text('No medications for this day', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            ...meds.map((med) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(
                      med.isActive ? Icons.medication : Icons.medication_outlined,
                      size: 18,
                      color: med.isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(med.name, style: theme.textTheme.bodyMedium)),
                    Text('${med.pillsTaken}/${med.totalPills}', style: theme.textTheme.labelSmall),
                  ]),
                )),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
