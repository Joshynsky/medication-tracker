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

  @override
  void initState() {
    super.initState();
    // Show helper text after 4 seconds of inactivity
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showHelperText = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pillCount = ref.watch(pillCountProvider);
    final notes = ref.watch(notesProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'How much do you have?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optional — skip if you\'re unsure.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Pill count
          Text(
            'Number of pills',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: pillCount),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g., 21, 30, 60',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.medication_outlined),
              suffixText: 'pills',
            ),
            onChanged: (value) {
              ref.read(pillCountProvider.notifier).state = value;
            },
          ),

          // Delayed helper text
          AnimatedOpacity(
            opacity: _showHelperText && pillCount.isEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'We\'ll count down so you know when to refill.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Notes
          Text(
            'Notes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Any special instructions?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: notes),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g., Take with food, avoid alcohol...',
              border: OutlineInputBorder(),
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.note_alt_outlined),
              ),
            ),
            onChanged: (value) {
              ref.read(notesProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}