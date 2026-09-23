import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MuscleSplitProgressCard extends StatelessWidget {
  final List<Map<String, dynamic>> muscleData;
  final Animation<double> animation;

  const MuscleSplitProgressCard({
    super.key,
    required this.muscleData,
    required this.animation,
  });

  void _showMuscleExercisesDialog(
    BuildContext context,
    Map<String, dynamic> muscleItem,
  ) {
    HapticFeedback.lightImpact();
    final List<Map<String, dynamic>> exercises =
        (muscleItem['exercises'] as List).cast<Map<String, dynamic>>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF191919),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFFF9700), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          muscleItem['muscle'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${muscleItem['sets']} serie efficaci (RPE ≥ 8)',
                          style: const TextStyle(
                            color: Color(0xFFFF9700),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),
                const Text(
                  'Esercizi che hanno generato lo stimolo:',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 10),
                ...exercises.map((ex) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF9700,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            color: Color(0xFFFF9700),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex['name'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Media: ${ex['avgWeight']} kg',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${ex['sets']} × ${ex['reps']}',
                            style: const TextStyle(
                              color: Color(0xFFFF9700),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hard Sets per Gruppo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Tocca per dettagli',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...muscleData.map((item) {
            final int sets = item['sets'];
            final int target = item['target'];
            final double percent = (sets / target).clamp(0.0, 1.0);
            final bool completed = sets >= target;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showMuscleExercisesDialog(context, item),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 7.0,
                  horizontal: 4.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              item['muscle'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white24,
                              size: 13,
                            ),
                          ],
                        ),
                        Text(
                          '$sets / $target set ${completed ? '✓' : ''}',
                          style: TextStyle(
                            color:
                                completed
                                    ? const Color(0xFFFF9700)
                                    : Colors.white54,
                            fontSize: 12,
                            fontWeight:
                                completed ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: percent * animation.value,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF141414),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item['color'] as Color,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
