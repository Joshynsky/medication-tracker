import 'package:flutter/material.dart';
import '../providers/timeline_provider.dart';

class DoseCard extends StatelessWidget {
  final TimeSlot timeSlot;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;

  const DoseCard({
    super.key,
    required this.timeSlot,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final timeDiff = timeSlot.time.difference(now);

    return Container(
      margin: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(timeDiff),
              style: theme.textTheme.titleMedium?.copyWith(
                color: _statusColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Time
          Text(
            timeSlot.timeLabel,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // Countdown for upcoming doses
          if (timeSlot.status == 'upcoming' && timeDiff.inHours < 12)
            Text(
              _countdownText(timeDiff),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 32),

          // Medication cards
          ...timeSlot.medications.map((med) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: timeSlot.isTaken
                  ? Colors.green.withOpacity(0.05)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: timeSlot.isTaken
                    ? Colors.green.withOpacity(0.3)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: timeSlot.isTaken
                        ? Colors.green.withOpacity(0.1)
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    timeSlot.isTaken ? Icons.check_circle : Icons.medication,
                    color: timeSlot.isTaken ? Colors.green : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        med.dosage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (med.totalPills > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${med.pillsRemaining} left',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          )),
          const SizedBox(height: 32),

          // Action buttons
          if (!timeSlot.isTaken) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle, size: 22),
                label: const Text('I took them all'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip this dose'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'All doses confirmed',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor() {
    switch (timeSlot.status) {
      case 'past':
        return timeSlot.isTaken ? Colors.green : Colors.red;
      case 'current':
        return Colors.orange;
      case 'upcoming':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(Duration timeDiff) {
    if (timeSlot.isTaken) return '✓ Completed';
    if (timeSlot.isMissed) return '✗ Missed';
    if (timeSlot.status == 'current') return '🔔 Now';
    if (timeSlot.status == 'upcoming') return '⏱ Upcoming';
    return '';
  }

  String _countdownText(Duration diff) {
    if (diff.inHours > 0) {
      return 'in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    return 'in ${diff.inMinutes}m';
  }
}
