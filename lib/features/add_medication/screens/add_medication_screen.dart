import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../providers/add_medication_provider.dart';
import '../widgets/step_indicator.dart';
import '../widgets/step_one_identify.dart';
import '../widgets/step_two_schedule.dart';
import '../widgets/step_three_quantity.dart';
import '../widgets/step_preview.dart';

class AddMedicationScreen extends ConsumerWidget {
  const AddMedicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(currentStepProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medication'),
        centerTitle: true,
        leading: currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (currentStep == totalFormSteps) {
                    ref.read(currentStepProvider.notifier).state = 2;
                  } else {
                    ref.read(currentStepProvider.notifier).state =
                        currentStep - 1;
                  }
                },
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
        actions: [
          if (currentStep < totalFormSteps)
            TextButton(
              onPressed: () {
                ref.read(currentStepProvider.notifier).state = totalFormSteps;
              },
              child: Text(
                'Skip to preview',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          if (currentStep < totalFormSteps) ...[
            const StepIndicator(),
            const SizedBox(height: 8),
            Text(
              'Step ${currentStep + 1} of $totalFormSteps',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const Divider(height: 32),
          Expanded(child: _buildStep(currentStep)),
          _buildBottomBar(context, ref, currentStep, theme),
        ],
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return const StepOneIdentify();
      case 1:
        return const StepTwoSchedule();
      case 2:
        return const StepThreeQuantity();
      case 3:
        return const StepPreview();
      default:
        return const StepOneIdentify();
    }
  }

  Widget _buildBottomBar(
    BuildContext context,
    WidgetRef ref,
    int currentStep,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (currentStep < totalFormSteps) ...[
              if (currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(currentStepProvider.notifier).state =
                          currentStep - 1;
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (currentStep > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    if (currentStep < totalFormSteps - 1) {
                      ref.read(currentStepProvider.notifier).state =
                          currentStep + 1;
                    } else {
                      ref.read(currentStepProvider.notifier).state =
                          totalFormSteps;
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    currentStep == totalFormSteps - 1 ? 'Preview' : 'Next',
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(currentStepProvider.notifier).state = 2;
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _saveMedication(context, ref),
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveMedication(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(medicationRepositoryProvider);
    final name = ref.read(medicationNameProvider);
    final dosage = ref.read(dosageProvider);
    final scheduleType = ref.read(scheduleTypeProvider);
    final times = ref.read(scheduleTimesProvider);
    final intervalHours = ref.read(intervalHoursProvider);
    final customDays = ref.read(customDaysProvider);
    final startDate = ref.read(startDateProvider);
    final pillCount = ref.read(pillCountProvider);
    final notes = ref.read(notesProvider);

    try {
      final patientId = await repository.ensureDefaultUserAndPatient();

      await repository.saveMedication(
        patientId: patientId,
        name: name.isEmpty ? 'Unnamed medication' : name,
        dosage: dosage,
        scheduleType: scheduleType,
        startDateTime: startDate,
        totalPills: int.tryParse(pillCount),
        notes: notes.isEmpty ? null : notes,
        times: times,
        intervalHours: intervalHours,
        customDays: customDays,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name saved! 💊'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(medicationRepositoryProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
