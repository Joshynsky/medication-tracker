import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../add_medication/screens/add_medication_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<Map<String, dynamic>>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final repository = ref.read(medicationRepositoryProvider);
    final patientId = await repository.ensureDefaultUserAndPatient();
    final medications = await repository.getMedications(patientId);
    final todaysDoses = await repository.getTodaysDoses(patientId);
    return {
      'medications': medications,
      'todaysDoses': todaysDoses,
    };
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data as Map<String, dynamic>?;
          final medications = data?['medications'] as List<dynamic>? ?? [];
          final todaysDoses = data?['todaysDoses'] as List<dynamic>? ?? [];

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Medications',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todaysDoses.isNotEmpty
                              ? '${todaysDoses.length} doses scheduled today'
                              : 'No medications scheduled for today',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (todaysDoses.isEmpty && medications.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No medications yet',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first medication to start tracking.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AddMedicationScreen(),
                                  ),
                                );
                                _refresh();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add your first medication'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (todaysDoses.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final dose = todaysDoses[index];
                        final doseTime = dose.scheduledTime;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.medication,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              'Medication',
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              'Scheduled for ${doseTime.hour.toString().padLeft(2, '0')}:${doseTime.minute.toString().padLeft(2, '0')}',
                            ),
                            trailing: FilledButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Dose confirmed! 💊'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Text('Take'),
                            ),
                          ),
                        );
                      },
                      childCount: todaysDoses.length,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddMedicationScreen(),
            ),
          );
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Medication'),
      ),
    );
  }
}
