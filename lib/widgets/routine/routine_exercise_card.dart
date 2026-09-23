import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/routine_item.dart';
import '../../models/exercise_type.dart';
import '../../utils/time_formatters.dart';

class RoutineExerciseCard extends StatelessWidget {
  final RoutineExerciseConfig config;
  final int index;
  final String? imagePath; // <-- Parametro immagine
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RoutineExerciseCard({
    super.key,
    required this.config,
    required this.index,
    this.imagePath,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
                const SizedBox(width: 10),

                // BOX IMMAGINE ESERCIZIO O FALLBACK MANUBRIO
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9700).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildThumbnail(imagePath),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.exerciseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${config.muscleGroup} ${config.isCompound ? '• Multiarticolare' : '• Isolamento'}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF9700).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Modifica la stringa dentro il Row della card:
                      Text(
                        config.exerciseType == ExerciseType.time
                            ? '${config.targetSets} × ${formatTimeSeconds(config.minSeconds)} - ${formatTimeSeconds(config.maxSeconds)}'
                            : '${config.targetSets} × ${config.minReps}-${config.maxReps}',
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${config.restSeconds}s',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_rounded,
                        color: Colors.white30,
                        size: 13,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? path) {
    const fallback = Icon(
      Icons.fitness_center_rounded,
      color: Color(0xFFFF9700),
      size: 20,
    );

    if (path == null || path.trim().isEmpty) return fallback;

    if (path.startsWith('assets/')) {
      final normalized = path
          .replaceAll('_start.', '-start.')
          .replaceAll('_peak.', '-peak.')
          .replaceAll('_main.', '-main.');
      return Image.asset(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return fallback;
  }
}
