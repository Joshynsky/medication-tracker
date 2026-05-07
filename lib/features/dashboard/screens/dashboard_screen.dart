import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets/wave_clipper.dart';
import '../../add_medication/screens/add_medication_screen.dart';
import '../../medication_detail/screens/detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 30), _tick);
  }

  void _tick() {
    if (mounted) {
      setState(() => _now = DateTime.now());
      Future.delayed(const Duration(seconds: 30), _tick);
    }
  }

  String _greeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Good morning! ☀️';
    if (hour < 17) return 'Good afternoon! 🌤️';
    return 'Good evening! 🌙';
  }

  String _formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final am = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }

  String _countdownText(Duration d) {
    if (d.inMinutes <= 0) return 'now';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  String _dosageDisplay(Medication med) {
    if (med.strengthValue != null &&
        med.strengthUnit != null &&
        med.strengthValue! > 0) {
      if (med.amountPerDose != null &&
          med.amountUnit != null &&
          med.amountPerDose! > 0) {
        return '${med.strengthValue!.toInt()}${med.strengthUnit} · Take ${med.amountPerDose!.toInt()} ${med.amountUnit}';
      }
      return '${med.strengthValue!.toInt()}${med.strengthUnit}';
    }
    return med.dosage;
  }

  int _windowMinutes(String scheduleType, int intervalHours) {
    switch (scheduleType) {
      case 'every_x_hours':
        return (intervalHours * 60) ~/ 5;
      case 'once_daily':
        return 120;
      default:
        return 60;
    }
  }

  bool _isInWindow(DateTime t, String scheduleType, int intervalHours) {
    return t.difference(_now).inMinutes.abs() <=
        _windowMinutes(scheduleType, intervalHours);
  }

  bool _isPastWindow(DateTime t, String scheduleType, int intervalHours) {
    return _now.difference(t).inMinutes >
        _windowMinutes(scheduleType, intervalHours);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashState = ref.watch(dashboardProvider);
    if (dashState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('MediTrack'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final meds = dashState.medications;
    final doses = dashState.todaysDoses;
    final taken = dashState.takenCount;
    final total = dashState.totalCount;
    final remaining = dashState.remainingCount;
    final notifier = ref.read(dashboardProvider.notifier);

    doses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    DoseEvent? nextDose;
    try {
      nextDose = doses.firstWhere((d) => d.status == 'pending');
    } catch (_) {
      if (doses.isNotEmpty) nextDose = doses.first;
    }

    String schedType = 'once_daily';
    int intervalH = 12;
    if (nextDose != null && meds.isNotEmpty) {
      try {
        final m = meds.firstWhere((x) => x.id == nextDose!.medicationId);
        schedType = m.scheduleType;
      } catch (_) {}
    }

    List<Medication> cardMeds = [];
    int pendingInSlot = 0, takenInSlot = 0;
    if (nextDose != null) {
      final slot = doses
          .where(
            (d) =>
                d.scheduledTime.hour == nextDose!.scheduledTime.hour &&
                d.scheduledTime.minute == nextDose.scheduledTime.minute,
          )
          .toList();
      pendingInSlot = slot.where((d) => d.status == 'pending').length;
      takenInSlot = slot.where((d) => d.status == 'taken').length;
      for (final d in slot) {
        try {
          cardMeds.add(meds.firstWhere((m) => m.id == d.medicationId));
        } catch (_) {}
      }
    }

    final inWindow =
        nextDose != null &&
        _isInWindow(nextDose!.scheduledTime, schedType, intervalH);
    final pastWindow =
        nextDose != null &&
        _isPastWindow(nextDose!.scheduledTime, schedType, intervalH);
    final diff = nextDose != null
        ? nextDose!.scheduledTime.difference(_now)
        : Duration.zero;
    final allDone = takenInSlot > 0 && pendingInSlot == 0;
    final allCompletedToday = total > 0 && taken >= total;

    final hour = nextDose != null ? nextDose!.scheduledTime.hour : _now.hour;
    final isMorning = hour < 12;
    final isAfternoon = hour >= 12 && hour < 17;

    final cardColors = allDone || allCompletedToday
        ? [Colors.green.shade400, Colors.green.shade300]
        : pastWindow
        ? [Colors.red.shade400, Colors.red.shade300]
        : isMorning
        ? [Colors.amber.shade400, Colors.orange.shade300]
        : isAfternoon
        ? [Colors.blue.shade400, Colors.lightBlue.shade300]
        : [Colors.purple.shade400, Colors.deepPurple.shade300];

    final cardIcon = allDone || allCompletedToday
        ? Icons.celebration
        : pastWindow
        ? Icons.warning_amber
        : isMorning
        ? Icons.wb_sunny
        : isAfternoon
        ? Icons.wb_cloudy
        : Icons.nightlight_round;

    String cardTitle, cardSubtitle;
    if (allCompletedToday) {
      cardTitle = 'All done! 🎉';
      cardSubtitle = 'No more doses today';
    } else if (allDone) {
      cardTitle = 'All taken!';
      cardSubtitle = 'Next: ${_formatTime(nextDose!.scheduledTime)}';
    } else if (pastWindow && pendingInSlot > 0) {
      cardTitle = 'Missed';
      cardSubtitle = _formatTime(nextDose!.scheduledTime);
    } else if (inWindow) {
      cardTitle = 'Take now';
      cardSubtitle = _formatTime(nextDose!.scheduledTime);
    } else {
      cardTitle = 'Next dose in';
      cardSubtitle = _countdownText(diff);
    }

    final timeDots = <String, String>{};
    for (final d in doses) {
      final k = _formatTime(d.scheduledTime);
      if (d.status == 'taken') {
        timeDots[k] = 'taken';
      } else if (timeDots[k] != 'taken') {
        timeDots[k] = d.status ?? 'pending';
      }
    }
    final sortedDots = timeDots.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('MediTrack'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _greeting(),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cardColors[0].withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 50),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: cardColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(cardIcon, color: Colors.white, size: 32),
                        const SizedBox(height: 10),
                        Text(
                          cardTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cardSubtitle,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (nextDose != null &&
                            !allCompletedToday &&
                            !pastWindow &&
                            pendingInSlot > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              inWindow ? '🔔 Window open' : '⏱ Upcoming',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (pastWindow && pendingInSlot > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Window passed',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (cardMeds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ...cardMeds.asMap().entries.map((entry) {
                          final med = entry.value;
                          final dose = doses.firstWhere(
                            (d) =>
                                d.medicationId == med.id &&
                                d.scheduledTime.hour ==
                                    nextDose!.scheduledTime.hour &&
                                d.scheduledTime.minute ==
                                    nextDose!.scheduledTime.minute,
                            orElse: () => nextDose!,
                          );
                          final isTaken = dose.status == 'taken';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isTaken
                                  ? Colors.green.withOpacity(0.06)
                                  : theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: isTaken
                                  ? Border.all(
                                      color: Colors.green.withOpacity(0.2),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isTaken
                                        ? Colors.green.withOpacity(0.12)
                                        : theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isTaken
                                        ? Icons.check_circle
                                        : Icons.medication,
                                    size: 20,
                                    color: isTaken
                                        ? Colors.green
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        _dosageDisplay(med),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (med.totalPills > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${med.pillsRemaining} left',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                if (inWindow && !isTaken) ...[
                                  const SizedBox(width: 10),
                                  FilledButton(
                                    onPressed: () => notifier.confirmDose(
                                      dose.id,
                                      dose.medicationId,
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      backgroundColor: cardColors[0],
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Take'),
                                  ),
                                ] else if (isTaken)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (inWindow && pendingInSlot > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    for (final d in doses.where(
                                      (d) =>
                                          d.scheduledTime.hour ==
                                              nextDose!.scheduledTime.hour &&
                                          d.scheduledTime.minute ==
                                              nextDose!.scheduledTime.minute &&
                                          d.status == 'pending',
                                    )) {
                                      notifier.snoozeDose(d.id);
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    side: BorderSide(
                                      color: Colors.orange.withOpacity(0.5),
                                    ),
                                  ),
                                  child: const Text(
                                    'Snooze',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    for (final d in doses.where(
                                      (d) =>
                                          d.scheduledTime.hour ==
                                              nextDose!.scheduledTime.hour &&
                                          d.scheduledTime.minute ==
                                              nextDose!.scheduledTime.minute &&
                                          d.status == 'pending',
                                    )) {
                                      notifier.confirmDose(
                                        d.id,
                                        d.medicationId,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                  ),
                                  label: const Text('I took them all'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: cardColors[0],
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (allDone && !allCompletedToday)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.celebration,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'All doses confirmed! 🎉',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (pastWindow && pendingInSlot > 0)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Dose window passed',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (allCompletedToday)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.celebration,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Great job today! 🌟',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (total > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$taken of $total taken',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              remaining > 0
                                  ? '$remaining remaining 🌟'
                                  : 'All done! 🎉',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        total > 0
                            ? '${((taken / total) * 100).round()}%'
                            : '0%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? taken / total : 0,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            if (sortedDots.isNotEmpty) ...[
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: sortedDots.map((time) {
                    final s = timeDots[time];
                    IconData ic;
                    Color c;
                    if (s == 'taken') {
                      ic = Icons.check_circle;
                      c = Colors.green;
                    } else if (s == 'missed') {
                      ic = Icons.cancel;
                      c = Colors.red;
                    } else {
                      ic = Icons.access_time;
                      c = theme.colorScheme.primary;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(ic, size: 14, color: c),
                            const SizedBox(width: 6),
                            Text(
                              time,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
          if (meds.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Your medications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...meds.map(
              (med) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicationDetailScreen(medication: med),
                    ),
                  ).then((_) => notifier.refresh()),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.medication,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _dosageDisplay(med),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (med.totalPills > 0)
                          Text(
                            '${med.pillsRemaining} left',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (meds.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No medications yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'Tap + to add your first',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
        ).then((_) => notifier.refresh()),
        icon: const Icon(Icons.add),
        label: const Text('Add Medication'),
      ),
    );
  }
}
