import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/mock_medication_repository.dart';
import '../../../shared/widgets/celebration_overlay.dart';
import '../../add_medication/screens/add_medication_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showCelebration = false;
  String _celebrationMessage = '';

  void _confirmDose(MockMedicationRepository repo, int doseId) {
    repo.confirmDose(doseId);
    setState(() {
      _celebrationMessage = 'Great job! Keep going! 💊';
      _showCelebration = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(mockRepositoryProvider);
    final medications = repository.getMedications();
    final todaysDoses = repository.getTodaysDoses();
    final theme = Theme.of(context);

    final takenCount = todaysDoses.where((d) => d.status == 'taken').length;
    final pendingCount = todaysDoses.where((d) => d.status == 'pending').length;
    final missedCount = todaysDoses.where((d) => d.status == 'missed').length;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('MediTrack'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$takenCount of ${todaysDoses.length} taken',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      missedCount > 0
                                          ? '$missedCount missed'
                                          : pendingCount > 0
                                              ? '$pendingCount remaining'
                                              : 'All done! 🎉',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CircularProgressIndicator(
                                      value: todaysDoses.isEmpty
                                          ? 0
                                          : takenCount / todaysDoses.length,
                                      backgroundColor: Colors.white.withOpacity(0.3),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 4,
                                    ),
                                  ),
                                  Text(
                                    todaysDoses.isEmpty
                                        ? '0%'
                                        : '${((takenCount / todaysDoses.length) * 100).round()}%',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Your Medications',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final med = medications[index];
                      final medDoses =
                          todaysDoses.where((d) => d.medicationId == med.id).toList();
                      return _MedicationCard(
                        medication: med,
                        doses: medDoses,
                        onConfirm: (doseId) => _confirmDose(repository, doseId),
                        onSkip: (doseId) {
                          repository.skipDose(doseId);
                          setState(() {});
                        },
                      );
                    },
                    childCount: medications.length,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AddMedicationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Medication'),
          ),
        ),
        // Celebration overlay
        if (_showCelebration)
          CelebrationOverlay(
            message: _celebrationMessage,
            onComplete: () {
              setState(() {
                _showCelebration = false;
              });
            },
          ),
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final MockMedication medication;
  final List<MockDoseEvent> doses;
  final Function(int) onConfirm;
  final Function(int) onSkip;

  const _MedicationCard({
    required this.medication,
    required this.doses,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        medication.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        medication.dosage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (medication.totalPills > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${medication.pillsRemaining} left',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            if (doses.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...doses.map((dose) => _DoseRow(
                    dose: dose,
                    onConfirm: () => onConfirm(dose.id),
                    onSkip: () => onSkip(dose.id),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  final MockDoseEvent dose;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;

  const _DoseRow({
    required this.dose,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr =
        '${dose.scheduledTime.hour.toString().padLeft(2, '0')}:${dose.scheduledTime.minute.toString().padLeft(2, '0')}';

    IconData icon;
    Color iconColor;
    String label;

    switch (dose.status) {
      case 'taken':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        label = 'Taken at $timeStr ✓';
        break;
      case 'missed':
        icon = Icons.cancel;
        iconColor = Colors.red;
        label = 'Missed at $timeStr ✗';
        break;
      case 'skipped':
        icon = Icons.skip_next;
        iconColor = Colors.orange;
        label = 'Skipped at $timeStr';
        break;
      default:
        icon = Icons.access_time;
        iconColor = theme.colorScheme.primary;
        label = 'Due at $timeStr';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: dose.status == 'pending'
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (dose.status == 'pending') ...[
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('Take'),
            ),
          ],
        ],
      ),
    );
  }
}
