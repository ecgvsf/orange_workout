import 'package:flutter/material.dart';
import '../../models/workout_set.dart';
import '../../utils/time_formatters.dart';

class CompletedExerciseRow extends StatelessWidget {
  final String exerciseName;
  final List<WorkoutSet> sets;
  final VoidCallback onDelete;

  const CompletedExerciseRow({
    super.key,
    required this.exerciseName,
    required this.sets,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Card Riepilogo Esercizio Concluso
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        exerciseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${sets.length} serie',
                      style: const TextStyle(
                        color: Color(0xFFFF9700),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sets
                      .map(
                        (s) =>
                            s.holdSeconds != null && s.holdSeconds! > 0
                                ? '${s.weight > 0 ? "${s.weight}kg × " : ""}${formatTimeSeconds(s.holdSeconds!)}'
                                : '${s.weight}kg × ${s.reps}',
                      )
                      .join(' • '),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Card Cestino Separata Affiancata
        InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
