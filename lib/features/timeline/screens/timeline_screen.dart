import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_provider.dart';
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
    final slots = ref.watch(timelineProvider);
    final theme = Theme.of(context);

    if (slots.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timeline'), centerTitle: true),
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.celebration_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('All done for today! 🎉', style: theme.textTheme.titleLarge),
          Text('No more doses scheduled.', style: theme.textTheme.bodyMedium),
        ])),
      );
    }

    final totalPending = slots.where((s) => !s.isTaken).length;
    final notifier = ref.read(dashboardProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Timeline'), centerTitle: true, actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Text('$totalPending remaining', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: slots.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final slot = slots[index];
              return SwipeableDoseCard(
                timeSlot: slot,
                onConfirmDose: (doseId) {
                  final dose = slot.doses.firstWhere((d) => d.id == doseId);
                  notifier.confirmDose(doseId, dose.medicationId);
                },
                onConfirmAll: () {
                  for (final dose in slot.doses.where((d) => d.status == 'pending')) {
                    notifier.confirmDose(dose.id, dose.medicationId);
                  }
                },
                onSnooze: () {
                  for (final dose in slot.doses.where((d) => d.status == 'pending')) {
                    notifier.snoozeDose(dose.id);
                  }
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slots.length, (index) {
            final isActive = _currentIndex == index;
            final slot = slots[index];
            Color dotColor;
            if (slot.isTaken) { dotColor = Colors.green; }
            else if (slot.isMissed) { dotColor = Colors.red; }
            else if (isActive) { dotColor = theme.colorScheme.primary; }
            else { dotColor = theme.colorScheme.surfaceContainerHighest; }
            return AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: isActive ? 24 : 8, height: 8, decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(4)));
          })),
        ),
      ]),
    );
  }
}
