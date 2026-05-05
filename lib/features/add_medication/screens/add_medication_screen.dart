import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                    ref.read(currentStepProvider.notifier).state = currentStep - 1;
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
          Expanded(
            child: _buildStep(currentStep),
          ),
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
                      ref.read(currentStepProvider.notifier).state = currentStep - 1;
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
                      ref.read(currentStepProvider.notifier).state = currentStep + 1;
                    } else {
                      ref.read(currentStepProvider.notifier).state = totalFormSteps;
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Medication saved! (Database offline in web mode)'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
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
}
