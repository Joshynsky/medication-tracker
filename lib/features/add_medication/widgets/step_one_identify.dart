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
  final _dosageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final name = ref.read(medicationNameProvider);
    final dosage = ref.read(dosageProvider);
    _nameController.text = name;
    _dosageController.text = dosage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerPhoto = ref.watch(photoOuterProvider);
    final innerPhoto = ref.watch(photoInnerProvider);
    final pillsPhoto = ref.watch(photoPillsProvider);
    final hasInner = ref.watch(hasInnerPackagingProvider);
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What are you taking?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Let\'s identify your medication together.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),

            if (!_photosSkipped) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Photos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: () => setState(() { _photosSkipped = true; ref.read(photoOuterProvider.notifier).state = 'skipped'; ref.read(photoPillsProvider.notifier).state = 'skipped'; }),
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Skip photos'),
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Photos help you identify the right medicine at the right time.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              _PhotoCard(label: 'Photo 1', title: 'Outer packaging', subtitle: 'The box, bottle, or tin', imagePath: outerPhoto, isRequired: true, onCapture: () => ref.read(photoOuterProvider.notifier).state = 'captured_placeholder'),
              const SizedBox(height: 12),
              if (outerPhoto.isNotEmpty && hasInner == null) ...[
                _InnerPackagingQuestion(onYes: () => ref.read(hasInnerPackagingProvider.notifier).state = true, onNo: () => ref.read(hasInnerPackagingProvider.notifier).state = false),
                const SizedBox(height: 12),
              ],
              if (hasInner == true) ...[
                _PhotoCard(label: 'Photo 2', title: 'Inner packaging', subtitle: 'Blister pack or strip', imagePath: innerPhoto, isRequired: false, onCapture: () => ref.read(photoInnerProvider.notifier).state = 'captured_placeholder'),
                const SizedBox(height: 12),
              ],
              if (hasInner != null || outerPhoto.isNotEmpty) ...[
                _PhotoCard(label: hasInner == true ? 'Photo 3' : 'Photo 2', title: 'The pills', subtitle: 'A clear photo of the pills themselves', imagePath: pillsPhoto, isRequired: true, onCapture: () => ref.read(photoPillsProvider.notifier).state = 'captured_placeholder'),
              ],
              const SizedBox(height: 32),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.photo_camera_outlined, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Photos skipped — you can add them later', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                  TextButton(onPressed: () => setState(() { _photosSkipped = false; ref.read(photoOuterProvider.notifier).state = ''; ref.read(photoPillsProvider.notifier).state = ''; }), child: const Text('Add photos')),
                ]),
              ),
              const SizedBox(height: 32),
            ],

            Text('Medication name', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                textDirection: TextDirection.ltr,
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'e.g., Amoxicillin, Metformin', border: OutlineInputBorder(), prefixIcon: Icon(Icons.medication_outlined)),
                onChanged: (value) => ref.read(medicationNameProvider.notifier).state = value,
              ),
            ),
            const SizedBox(height: 20),

            Text('Dosage', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                textDirection: TextDirection.ltr,
                controller: _dosageController,
                decoration: const InputDecoration(hintText: 'e.g., 500mg, 10ml, 1 tablet', border: OutlineInputBorder(), prefixIcon: Icon(Icons.straighten_outlined)),
                onChanged: (value) => ref.read(dosageProvider.notifier).state = value,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String label; final String title; final String subtitle; final String imagePath; final bool isRequired; final VoidCallback onCapture;
  const _PhotoCard({required this.label, required this.title, required this.subtitle, required this.imagePath, required this.isRequired, required this.onCapture});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); final isCaptured = imagePath.isNotEmpty;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: isCaptured ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: isCaptured ? 2 : 1), borderRadius: BorderRadius.circular(12)),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onCapture, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: isCaptured ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Icon(isCaptured ? Icons.check_circle : Icons.camera_alt_outlined, color: isCaptured ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), if (isRequired) ...[const SizedBox(width: 4), Text('*', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold))]]),
          const SizedBox(height: 2),
          Text(isCaptured ? 'Photo captured ✓' : subtitle, style: theme.textTheme.bodySmall?.copyWith(color: isCaptured ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
      ])))),
    );
  }
}

class _InnerPackagingQuestion extends StatelessWidget {
  final VoidCallback onYes; final VoidCallback onNo;
  const _InnerPackagingQuestion({required this.onYes, required this.onNo});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Is your medication stored inside another pack within the box?', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text('Like a blister pack or foil strip.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: onYes, style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Yes, let me photograph it'))),
        const SizedBox(width: 12),
        Expanded(child: TextButton(onPressed: onNo, child: const Text('No, skip to pills'))),
      ]),
    ]));
  }
}
