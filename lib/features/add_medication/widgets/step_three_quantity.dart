import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/add_medication_provider.dart';

class StepThreeQuantity extends ConsumerStatefulWidget {
  const StepThreeQuantity({super.key});

  @override
  ConsumerState<StepThreeQuantity> createState() => _StepThreeQuantityState();
}

class _StepThreeQuantityState extends ConsumerState<StepThreeQuantity> {
  bool _showHelperText = false;
  final _pillController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final pillCount = ref.read(pillCountProvider);
    final notes = ref.read(notesProvider);
    _pillController.text = pillCount;
    _notesController.text = notes;
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showHelperText = true);
    });
  }

  @override
  void dispose() {
    _pillController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pillCount = ref.watch(pillCountProvider);
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How much do you have?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Optional — skip if you\'re unsure.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),

            Text('Number of pills', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                textDirection: TextDirection.ltr,
                controller: _pillController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g., 21, 30, 60',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication_outlined),
                  suffixText: 'pills',
                ),
                onChanged: (value) => ref.read(pillCountProvider.notifier).state = value,
              ),
            ),

            AnimatedOpacity(
              opacity: _showHelperText && pillCount.isEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('We\'ll count down so you know when to refill.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text('Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Any special instructions?', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                textDirection: TextDirection.ltr,
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g., Take with food, avoid alcohol...',
                  border: OutlineInputBorder(),
                  prefixIcon: Padding(padding: EdgeInsets.only(bottom: 48), child: Icon(Icons.note_alt_outlined)),
                ),
                onChanged: (value) => ref.read(notesProvider.notifier).state = value,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
