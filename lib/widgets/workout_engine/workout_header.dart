import 'package:flutter/material.dart';

class WorkoutHeader extends StatelessWidget {
  final String routineName;
  final int elapsedSeconds;
  final double progress;
  final bool hasRoutine;
  final VoidCallback onClose;
  final VoidCallback onFinish;

  const WorkoutHeader({
    super.key,
    required this.routineName,
    required this.elapsedSeconds,
    required this.progress,
    required this.hasRoutine,
    required this.onClose,
    required this.onFinish,
  });

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: onClose,
              ),
              Column(
                children: [
                  Text(
                    routineName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatTimer(elapsedSeconds),
                    style: const TextStyle(
                      color: Color(0xFFFF9700),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9700),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'FINE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        if (hasRoutine)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF9700),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
