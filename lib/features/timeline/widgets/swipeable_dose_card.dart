import 'package:flutter/material.dart';
import '../providers/timeline_provider.dart';
import '../../../shared/widgets/wave_clipper.dart';

class SwipeableDoseCard extends StatefulWidget {
  final TimeSlot timeSlot;
  final Function(int doseId) onConfirmDose;
  final VoidCallback onConfirmAll;
  final VoidCallback onSnooze;

  const SwipeableDoseCard({
    super.key,
    required this.timeSlot,
    required this.onConfirmDose,
    required this.onConfirmAll,
    required this.onSnooze,
  });

  @override
  State<SwipeableDoseCard> createState() => _SwipeableDoseCardState();
}

class _SwipeableDoseCardState extends State<SwipeableDoseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  int? _celebratingId;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scale = Tween(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _celebrate(int doseId) {
    setState(() => _celebratingId = doseId);
    _anim.forward().then((_) => _anim.reverse()).then((_) {
      if (mounted) {
        setState(() => _celebratingId = null);
        widget.onConfirmDose(doseId);
      }
    });
  }

  bool _isInWindow() {
    final now = DateTime.now();
    final doseTime = widget.timeSlot.time;
    final diff = now.difference(doseTime);
    return diff.inMinutes >= -60 && diff.inMinutes <= 60;
  }

  bool _isPastWindow() {
    final now = DateTime.now();
    final doseTime = widget.timeSlot.time;
    return now.difference(doseTime).inMinutes > 60;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final diff = widget.timeSlot.time.difference(now);
    final pending = widget.timeSlot.doses
        .where((d) => d.status == 'pending')
        .length;
    final taken = widget.timeSlot.doses
        .where((d) => d.status == 'taken')
        .length;
    final total = widget.timeSlot.doses.length;
    final hour = widget.timeSlot.time.hour;
    final isMorning = hour < 12;
    final isAfternoon = hour >= 12 && hour < 17;
    final inWindow = _isInWindow();
    final pastWindow = _isPastWindow();

    final headerColors = widget.timeSlot.isTaken
        ? [Colors.green.shade400, Colors.green.shade300]
        : isMorning
        ? [Colors.amber.shade500, Colors.orange.shade400]
        : isAfternoon
        ? [Colors.blue.shade500, Colors.lightBlue.shade400]
        : [Colors.purple.shade500, Colors.deepPurple.shade400];

    final glowColor = widget.timeSlot.isTaken
        ? Colors.green
        : isMorning
        ? Colors.amber.shade200
        : isAfternoon
        ? Colors.blue.shade200
        : Colors.purple.shade200;

    final headerIcon = isMorning
        ? Icons.wb_sunny
        : isAfternoon
        ? Icons.wb_cloudy
        : Icons.nightlight_round;

    String statusText;
    if (widget.timeSlot.isTaken) {
      statusText = 'All done! 🎉';
    } else if (taken > 0 && pending > 0) {
      statusText = '$taken of $total taken';
    } else if (pastWindow && pending > 0) {
      statusText = 'Missed';
    } else if (inWindow) {
      statusText = 'Take now';
    } else if (diff.isNegative) {
      statusText = 'Upcoming';
    } else {
      statusText = 'Missed';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wave header - full width, content spanning edges
            ClipPath(
              clipper: WaveClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 70),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  gradient: LinearGradient(
                    colors: headerColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: icon
                    Icon(headerIcon, color: Colors.white, size: 36),
                    const SizedBox(width: 16),
                    // Center: time + countdown + status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.timeSlot.timeLabel,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (diff.inMinutes > 0 && diff.inHours < 12) ...[
                            const SizedBox(height: 2),
                            Text(
                              'in ${diff.inHours > 0 ? '${diff.inHours}h ' : ''}${diff.inMinutes.remainder(60)}m',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              statusText,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right: decorative dots or empty for balance
                    if (total > 0)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$taken/$total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (total > 0 && !widget.timeSlot.isTaken) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: total > 0 ? taken / total : 0,
                                minHeight: 5,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(
                                  headerColors[0],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            pending > 0 ? '$pending left' : 'Done!',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: headerColors[0],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    ...widget.timeSlot.medications.asMap().entries.map((e) {
                      final i = e.key;
                      final med = e.value;
                      final dose = widget.timeSlot.doses[i];
                      final isTaken = dose.status == 'taken';
                      final isCeleb = _celebratingId == dose.id;
                      final showTakeButton =
                          inWindow && !isTaken && !widget.timeSlot.isTaken;

                      return AnimatedScale(
                        scale: isCeleb ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isTaken
                                ? Colors.green.withOpacity(0.06)
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: isTaken
                                ? Border.all(
                                    color: Colors.green.withOpacity(0.2),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isTaken
                                      ? Colors.green.withOpacity(0.12)
                                      : theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isTaken
                                      ? Icons.check_circle
                                      : Icons.medication,
                                  key: ValueKey(isTaken),
                                  color: isTaken
                                      ? Colors.green
                                      : theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isTaken
                                                ? Colors.green
                                                : null,
                                          ),
                                    ),
                                    Text(
                                      med.dosage,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (med.totalPills > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${med.pillsRemaining}',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                ),
                              if (showTakeButton)
                                FilledButton(
                                  onPressed: () => _celebrate(dose.id),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    backgroundColor: headerColors[0],
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Take',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if (isTaken)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    if (inWindow && !widget.timeSlot.isTaken) ...[
                      if (pending > 1) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onSnooze,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: BorderSide(
                                    color: Colors.orange.withOpacity(0.5),
                                  ),
                                ),
                                child: const Text(
                                  'Snooze',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: widget.onConfirmAll,
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text('I took the rest'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: headerColors[0],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (pending == 1) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.onSnooze,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(
                                color: Colors.orange.withOpacity(0.5),
                              ),
                            ),
                            child: const Text(
                              'Snooze',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ),
                      ],
                    ] else if (pastWindow && !widget.timeSlot.isTaken) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Dose window passed',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (widget.timeSlot.isTaken) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.celebration,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'All done! 🎉',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
