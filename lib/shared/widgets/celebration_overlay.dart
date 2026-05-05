import 'package:flutter/material.dart';

class CelebrationOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onComplete;

  const CelebrationOverlay({
    super.key,
    required this.message,
    required this.onComplete,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  final List<_ConfettiPiece> _confetti = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Generate confetti pieces
    for (int i = 0; i < 30; i++) {
      _confetti.add(_ConfettiPiece(
        left: (i * 37) % 100,
        delay: (i * 0.05),
        color: [
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.pink,
          Colors.yellow,
        ][i % 6],
      ));
    }

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Stack(
            children: [
              // Semi-transparent background
              Container(
                color: Colors.black.withOpacity(0.4),
              ),
              // Confetti
              ..._confetti.map((c) => _buildConfetti(c)),
              // Center content
              Center(
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    margin: const EdgeInsets.all(40),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Dose Confirmed!',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfetti(_ConfettiPiece piece) {
    final progress = (_controller.value - piece.delay).clamp(0.0, 1.0);
    if (progress <= 0) return const SizedBox.shrink();

    return Positioned(
      left: piece.left / 100 * MediaQuery.of(context).size.width,
      top: -20 + (progress * MediaQuery.of(context).size.height),
      child: Transform.rotate(
        angle: progress * 3.14 * 4,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: piece.color,
            borderRadius: BorderRadius.circular(
              progress < 0.5 ? 0 : 4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  final double left;
  final double delay;
  final Color color;

  _ConfettiPiece({
    required this.left,
    required this.delay,
    required this.color,
  });
}
