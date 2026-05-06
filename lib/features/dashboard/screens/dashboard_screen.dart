import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../data/local/database.dart';
import '../../add_medication/screens/add_medication_screen.dart';
import '../../medication_detail/screens/detail_screen.dart';

final dashboardRefreshProvider = StateProvider<int>((ref) => 0);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! ☀️';
    if (hour < 17) return 'Good afternoon! 🌤️';
    return 'Good evening! 🌙';
  }

  @override
  void initState() {
    super.initState();
    ref.read(dashboardRefreshProvider);
  }

  Future<Map<String, dynamic>> _loadData() async {
    final repository = ref.read(medicationRepositoryProvider);
    final patientId = await repository.ensureDefaultUserAndPatient();
    final medications = await repository.getMedications(patientId);
    final todaysDoses = await repository.getTodaysDoses(patientId);
    return {'medications': medications, 'todaysDoses': todaysDoses};
  }

  void _refresh() {
    ref.read(dashboardRefreshProvider.notifier).state++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(dashboardRefreshProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MediTrack'), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Error loading data',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          final data = snapshot.data!;
          final medications = data['medications'] as List<Medication>;
          final todaysDoses = data['todaysDoses'] as List<DoseEvent>;
          final takenCount = todaysDoses
              .where((d) => d.status == 'taken')
              .length;
          final totalCount = todaysDoses.length;
          final remainingCount = totalCount - takenCount;

          todaysDoses.sort(
            (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
          );
          DoseEvent? nextDose;
          try {
            nextDose = todaysDoses.firstWhere((d) => d.status == 'pending');
          } catch (_) {
            nextDose = null;
          }

          List<Medication> nextDoseMeds = [];
          if (nextDose != null) {
            for (final dose in todaysDoses.where(
              (d) =>
                  d.scheduledTime.hour == nextDose!.scheduledTime.hour &&
                  d.scheduledTime.minute == nextDose.scheduledTime.minute,
            )) {
              try {
                nextDoseMeds.add(
                  medications.firstWhere((m) => m.id == dose.medicationId),
                );
              } catch (_) {}
            }
          }

          final timeSlots = <String, String>{};
          for (final dose in todaysDoses) {
            final key =
                '${dose.scheduledTime.hour.toString().padLeft(2, '0')}:${dose.scheduledTime.minute.toString().padLeft(2, '0')}';
            if (dose.status == 'taken') {
              timeSlots[key] = 'taken';
            } else if (timeSlots[key] != 'taken') {
              timeSlots[key] = dose.status;
            }
          }
          final sortedSlots = timeSlots.keys.toList()..sort();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  _greeting(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                if (nextDose != null && nextDoseMeds.isNotEmpty) ...[
                  _NextDoseCard(
                    timeStr:
                        '${nextDose!.scheduledTime.hour.toString().padLeft(2, '0')}:${nextDose.scheduledTime.minute.toString().padLeft(2, '0')}',
                    timeDiff: nextDose.scheduledTime.difference(DateTime.now()),
                    medications: nextDoseMeds,
                    onConfirm: () async {
                      final repo = ref.read(medicationRepositoryProvider);
                      for (final dose in todaysDoses.where(
                        (d) =>
                            d.scheduledTime.hour ==
                                nextDose!.scheduledTime.hour &&
                            d.scheduledTime.minute ==
                                nextDose!.scheduledTime.minute,
                      )) {
                        await repo.confirmDose(dose.id, dose.medicationId);
                      }
                      _refresh();
                    },
                    onSnooze: () async {
                      final repo = ref.read(medicationRepositoryProvider);
                      for (final dose in todaysDoses.where(
                        (d) =>
                            d.scheduledTime.hour ==
                                nextDose!.scheduledTime.hour &&
                            d.scheduledTime.minute ==
                                nextDose!.scheduledTime.minute,
                      )) {
                        await repo.snoozeDose(dose.id);
                      }
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                if (totalCount > 0) ...[
                  Text(
                    'Today\'s progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                                    '$takenCount of $totalCount taken',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    remainingCount > 0
                                        ? '$remainingCount remaining 🌟'
                                        : 'All done! 🎉',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              totalCount > 0
                                  ? '${((takenCount / totalCount) * 100).round()}%'
                                  : '0%',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalCount > 0 ? takenCount / totalCount : 0,
                            minHeight: 8,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sortedSlots.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: sortedSlots.map((time) {
                          final status = timeSlots[time];
                          IconData icon;
                          Color color;
                          if (status == 'taken') {
                            icon = Icons.check_circle;
                            color = Colors.green;
                          } else if (status == 'missed') {
                            icon = Icons.cancel;
                            color = Colors.red;
                          } else if (status == 'pending') {
                            icon = Icons.access_time;
                            color = theme.colorScheme.primary;
                          } else {
                            icon = Icons.circle_outlined;
                            color = Colors.grey;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Row(
                              children: [
                                Icon(icon, size: 16, color: color),
                                const SizedBox(width: 4),
                                Text(time, style: theme.textTheme.labelSmall),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
                if (medications.isNotEmpty) ...[
                  Text(
                    'Your medications',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...medications.map(
                    (med) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MedicationDetailScreen(medication: med),
                          ),
                        ).then((_) => _refresh()),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.medication,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      med.dosage,
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
                                Text(
                                  '${med.pillsRemaining} left',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (medications.isEmpty)
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
                          const SizedBox(height: 4),
                          Text(
                            'Tap + to add your first medication',
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
          ).then((_) => _refresh());
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Medication'),
      ),
    );
  }
}

class _NextDoseCard extends StatelessWidget {
  final String timeStr;
  final Duration timeDiff;
  final List<Medication> medications;
  final VoidCallback onConfirm;
  final VoidCallback onSnooze;
  const _NextDoseCard({
    required this.timeStr,
    required this.timeDiff,
    required this.medications,
    required this.onConfirm,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Up next',
            style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (timeDiff.inMinutes > 0 && timeDiff.inHours < 12)
            Text(
              'in ${timeDiff.inHours > 0 ? '${timeDiff.inHours}h ' : ''}${timeDiff.inMinutes.remainder(60)}m',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
          const SizedBox(height: 20),
          ...medications.map(
            (med) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medication, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      med.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      med.dosage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSnooze,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Snooze'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'I took them',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
