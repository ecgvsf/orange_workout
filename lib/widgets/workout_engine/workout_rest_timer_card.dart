import 'package:flutter/material.dart';

class WorkoutRestTimerCard extends StatelessWidget {
  final int restRemaining;
  final int initialRestDuration;
  final VoidCallback onSkip;
  final ValueChanged<int> onAddTime;

  const WorkoutRestTimerCard({
    super.key,
    required this.restRemaining,
    required this.initialRestDuration,
    required this.onSkip,
    required this.onAddTime,
  });

  @override
  Widget build(BuildContext context) {
    if (restRemaining <= 0) return const SizedBox.shrink();

    final double progress = (restRemaining /
            (initialRestDuration > 0 ? initialRestDuration : 1))
        .clamp(0.0, 1.0);
    final minutes = (restRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (restRemaining % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1610),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9700).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9700).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_rounded,
                      color: Color(0xFFFF9700),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'RECUPERO IN CORSO',
                    style: TextStyle(
                      color: Color(0xFFFF9700),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onSkip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'SALTA',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'sec',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFF9700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAddButton('+15s', () => onAddTime(15)),
              const SizedBox(width: 10),
              _buildAddButton('+30s', () => onAddTime(30)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
