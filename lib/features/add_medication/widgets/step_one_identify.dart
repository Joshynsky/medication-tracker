import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_medication_provider.dart';

class StepOneIdentify extends ConsumerStatefulWidget {
  const StepOneIdentify({super.key});
  @override
  ConsumerState<StepOneIdentify> createState() => _StepOneIdentifyState();
}

class _StepOneIdentifyState extends ConsumerState<StepOneIdentify> {
  bool _photosSkipped = false;
  final _nameController = TextEditingController();
  final _strengthController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = ref.read(medicationNameProvider);
    _strengthController.text = ref.read(strengthValueProvider);
    _amountController.text = ref.read(amountPerDoseProvider);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _forms = const [
    {'value': 'pills', 'label': '💊 Pills / Tablets'},
    {'value': 'liquid', 'label': '💧 Liquid / Syrup'},
    {'value': 'ointment', 'label': '🧴 Ointment / Cream'},
    {'value': 'injection', 'label': '💉 Injection'},
    {'value': 'drops', 'label': '👁️ Eye / Ear drops'},
    {'value': 'patch', 'label': '🩹 Patch'},
    {'value': 'other', 'label': '📦 Other'},
  ];

  List<String> _unitsFor(String form) {
    switch (form) {
      case 'pills':
        return ['mg', 'mcg', 'g', 'IU'];
      case 'liquid':
        return ['ml', 'tbsp', 'tsp'];
      case 'injection':
        return ['ml', 'units', 'mg'];
      default:
        return [''];
    }
  }

  List<String> _amountUnitsFor(String form) {
    switch (form) {
      case 'pills':
        return ['tablet', 'capsule', 'pill'];
      case 'liquid':
        return ['ml', 'teaspoon', 'tablespoon', 'capful'];
      case 'ointment':
        return ['application', 'pea-sized', 'thin layer'];
      case 'injection':
        return ['ml', 'units'];
      case 'drops':
        return ['drop', 'drops'];
      case 'patch':
        return ['patch'];
      default:
        return ['dose'];
    }
  }

  bool get _showStrength =>
      ['pills', 'liquid', 'injection'].contains(ref.watch(formProvider));
  bool get _showAmount => !['ointment'].contains(ref.watch(formProvider));

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(formProvider);
    final strengthUnit = ref.watch(strengthUnitProvider);
    final amountUnit = ref.watch(amountUnitProvider);
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What are you taking?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Let\'s identify your medication together.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Name
            Text(
              'Medication name',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              textDirection: TextDirection.ltr,
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g., Amoxicillin',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medication_outlined),
              ),
              onChanged: (v) =>
                  ref.read(medicationNameProvider.notifier).state = v,
            ),
            const SizedBox(height: 20),

            // Form
            Text(
              'Form',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: form,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _forms
                  .map(
                    (f) => DropdownMenuItem<String>(
                      value: f['value'],
                      child: Text(f['label']!),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(formProvider.notifier).state = v;
                  ref.read(strengthUnitProvider.notifier).state = _unitsFor(
                    v,
                  ).first;
                  ref.read(amountUnitProvider.notifier).state = _amountUnitsFor(
                    v,
                  ).first;
                }
              },
            ),
            const SizedBox(height: 20),

            // Strength
            if (_showStrength) ...[
              Text(
                'Strength',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      textDirection: TextDirection.ltr,
                      controller: _strengthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'e.g., 500',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          ref.read(strengthValueProvider.notifier).state = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: strengthUnit,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _unitsFor(form)
                          .map(
                            (u) => DropdownMenuItem<String>(
                              value: u,
                              child: Text(u),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null)
                          ref.read(strengthUnitProvider.notifier).state = v;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Amount per dose
            if (_showAmount) ...[
              Text(
                'How much per dose?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Take ', style: TextStyle(fontSize: 15)),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      textDirection: TextDirection.ltr,
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (v) =>
                          ref.read(amountPerDoseProvider.notifier).state = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: amountUnit,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _amountUnitsFor(form)
                          .map(
                            (u) => DropdownMenuItem<String>(
                              value: u,
                              child: Text(
                                u,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null)
                          ref.read(amountUnitProvider.notifier).state = v;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Photos
            if (!_photosSkipped) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Photos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _photosSkipped = true;
                      ref.read(photoOuterProvider.notifier).state = 'skipped';
                      ref.read(photoPillsProvider.notifier).state = 'skipped';
                    }),
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Skip photos'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PhotoCard(
                label: 'Photo 1',
                title: 'Packaging',
                subtitle: 'Box, bottle, or tin',
                imagePath: ref.watch(photoOuterProvider),
                isRequired: false,
                onCapture: () =>
                    ref.read(photoOuterProvider.notifier).state = 'captured',
              ),
              const SizedBox(height: 8),
              _PhotoCard(
                label: 'Photo 2',
                title: 'The medication itself',
                subtitle: 'Pills, liquid, etc.',
                imagePath: ref.watch(photoPillsProvider),
                isRequired: false,
                onCapture: () =>
                    ref.read(photoPillsProvider.notifier).state = 'captured',
              ),
              const SizedBox(height: 24),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Photos skipped',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _photosSkipped = false),
                      child: const Text('Add photos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String label, title, subtitle, imagePath;
  final bool isRequired;
  final VoidCallback onCapture;
  const _PhotoCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.isRequired,
    required this.onCapture,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captured = imagePath.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: captured
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onCapture,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: captured
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  captured ? Icons.check_circle : Icons.camera_alt_outlined,
                  size: 20,
                  color: captured
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      captured ? 'Captured ✓' : subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label, style: theme.textTheme.labelSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
