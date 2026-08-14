import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../shared/widgets/notification_permission_dialog.dart';
import '../providers/add_medication_provider.dart';
import '../widgets/step_indicator.dart';
import '../widgets/step_one_identify.dart';
import '../widgets/step_two_schedule.dart';
import '../widgets/step_three_quantity.dart';
import '../widgets/step_preview.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  /// When set, the wizard edits this existing medication instead of
  /// creating a new one. The caller is responsible for populating the
  /// wizard's fields beforehand (see populateAddMedicationStateForEdit) --
  /// this screen doesn't fetch/pre-fill on its own.
  final int? medicationId;

  const AddMedicationScreen({super.key, this.medicationId});

  @override
  ConsumerState<AddMedicationScreen> createState() =>
      _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  bool _isSaving = false;
  bool get _isEditing => widget.medicationId != null;

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(currentStepProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
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
          _buildBottomBar(context, currentStep, theme),
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
    int currentStep,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  onPressed: _isSaving ? null : () => _saveMedication(context),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
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

  Future<void> _saveMedication(BuildContext context) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

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
      final editingId = widget.medicationId;
      if (editingId != null) {
        await repository.updateMedication(
          medicationId: editingId,
          name: name.isEmpty ? 'Unnamed medication' : name,
          dosage: dosage,
          scheduleType: scheduleType,
          startDateTime: startDate,
          totalPills: int.tryParse(pillCount),
          notes: notes.isEmpty ? null : notes,
          form: ref.read(formProvider),
          strengthValue: double.tryParse(ref.read(strengthValueProvider)),
          strengthUnit: ref.read(strengthUnitProvider),
          amountPerDose: double.tryParse(ref.read(amountPerDoseProvider)),
          amountUnit: ref.read(amountUnitProvider),
          quantityUnit: ref.read(quantityUnitProvider),
          times: times,
          intervalHours: intervalHours,
          customDays: customDays,
        );
      } else {
        final patientId = await repository.ensureDefaultUserAndPatient();
        await repository.saveMedication(
          patientId: patientId,
          name: name.isEmpty ? 'Unnamed medication' : name,
          dosage: dosage,
          scheduleType: scheduleType,
          startDateTime: startDate,
          totalPills: int.tryParse(pillCount),
          notes: notes.isEmpty ? null : notes,
          form: ref.read(formProvider),
          strengthValue: double.tryParse(ref.read(strengthValueProvider)),
          strengthUnit: ref.read(strengthUnitProvider),
          amountPerDose: double.tryParse(ref.read(amountPerDoseProvider)),
          amountUnit: ref.read(amountUnitProvider),
          quantityUnit: ref.read(quantityUnitProvider),
          times: times,
          intervalHours: intervalHours,
          customDays: customDays,
        );

        if (context.mounted) {
          await NotificationPermissionDialog.showIfNeeded(context, ref);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '$name updated! 💊' : '$name saved! 💊'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(medicationRepositoryProvider);
        // Captured once, then reused for both pops -- re-deriving
        // Navigator.of(context) after the first pop risks operating on a
        // context whose widget is already being torn down.
        final navigator = Navigator.of(context);
        navigator.pop();
        // Editing is reached via the medication's detail screen, which was
        // showing a now-stale snapshot of the medication (it doesn't
        // re-fetch on its own) -- pop it too, back to the Dashboard, which
        // already refreshes itself when a pushed screen returns.
        if (_isEditing) {
          navigator.pop();
        }
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
