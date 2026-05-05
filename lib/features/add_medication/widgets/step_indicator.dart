import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_medication_provider.dart';

class StepIndicator extends ConsumerWidget {
  const StepIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(currentStepProvider);
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalFormSteps, (index) {
        final isActive = index == currentStep;
        final isCompleted = index < currentStep;
        final isLast = index == totalFormSteps - 1;

        return Row(
          children: [
            // The dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isActive ? 36 : 12,
              height: 12,
              decoration: BoxDecoration(
                color: isActive || isCompleted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // The connecting line
            if (!isLast)
              Container(
                width: 32,
                height: 2,
                color: isCompleted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
              ),
          ],
        );
      }),
    );
  }
}