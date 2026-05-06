import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/medication_repository.dart';
import '../providers/timeline_provider.dart';
import '../widgets/swipeable_dose_card.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(timelineProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline'), centerTitle: true),
      body: slotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (slots) {
          if (slots.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.celebration_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All done for today! 🎉',
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    'No more doses scheduled.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final totalPending = slots.where((s) => !s.isTaken).length;

          return Column(
            children: [
              // Pending count
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalPending remaining',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slots.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final repo = ref.read(medicationRepositoryProvider);

                    return SwipeableDoseCard(
                      timeSlot: slot,
                      onConfirmDose: (doseId) async {
                        final dose = slot.doses.firstWhere(
                          (d) => d.id == doseId,
                        );
                        await repo.confirmDose(doseId, dose.medicationId);
                        ref.invalidate(timelineProvider);
                      },
                      onConfirmAll: () async {
                        for (final dose in slot.doses.where(
                          (d) => d.status == 'pending',
                        )) {
                          await repo.confirmDose(dose.id, dose.medicationId);
                        }
                        ref.invalidate(timelineProvider);
                      },
                      onSnooze: () async {
                        for (final dose in slot.doses.where(
                          (d) => d.status == 'pending',
                        )) {
                          await repo.snoozeDose(dose.id);
                        }
                        ref.invalidate(timelineProvider);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(slots.length, (index) {
                    final isActive = _currentIndex == index;
                    final slot = slots[index];
                    Color dotColor;
                    if (slot.isTaken) {
                      dotColor = Colors.green;
                    } else if (slot.isMissed) {
                      dotColor = Colors.red;
                    } else if (isActive) {
                      dotColor = theme.colorScheme.primary;
                    } else {
                      dotColor = theme.colorScheme.surfaceContainerHighest;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
