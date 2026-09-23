import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/routine_item.dart';
import '../../models/exercise_type.dart';

class RoutineExerciseEditorSheet extends StatelessWidget {
  final RoutineExerciseConfig config;
  final VoidCallback onChanged;

  const RoutineExerciseEditorSheet({
    super.key,
    required this.config,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required RoutineExerciseConfig config,
    required VoidCallback onChanged,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) =>
              RoutineExerciseEditorSheet(config: config, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTime = config.exerciseType == ExerciseType.time;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                config.exerciseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Serie
              _buildEditorRow(
                label: 'Numero di Serie',
                valueDisplay: '${config.targetSets}',
                onMinus: () {
                  if (config.targetSets > 1) {
                    HapticFeedback.selectionClick();
                    setModalState(() => config.targetSets--);
                    onChanged();
                  }
                },
                onPlus: () {
                  if (config.targetSets < 15) {
                    HapticFeedback.selectionClick();
                    setModalState(() => config.targetSets++);
                    onChanged();
                  }
                },
              ),
              const SizedBox(height: 12),

              // Reps Minime e Massime o Tempo
              Row(
                children: [
                  Expanded(
                    child: _buildEditorRow(
                      label: isTime ? 'Sec Min' : 'Reps Min',
                      valueDisplay:
                          isTime
                              ? '${config.minSeconds}s'
                              : '${config.minReps}',
                      onMinus: () {
                        if (isTime
                            ? config.minSeconds > 5
                            : config.minReps > 1) {
                          HapticFeedback.selectionClick();
                          setModalState(() {
                            isTime ? config.minSeconds -= 5 : config.minReps--;
                          });
                          onChanged();
                        }
                      },
                      onPlus: () {
                        if (isTime
                            ? config.minSeconds < 300
                            : config.minReps < 40) {
                          HapticFeedback.selectionClick();
                          setModalState(() {
                            if (isTime) {
                              config.minSeconds += 5;
                              if (config.maxSeconds < config.minSeconds)
                                config.maxSeconds = config.minSeconds;
                            } else {
                              config.minReps++;
                              if (config.maxReps < config.minReps)
                                config.maxReps = config.minReps;
                            }
                          });
                          onChanged();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildEditorRow(
                      label: isTime ? 'Sec Max' : 'Reps Max',
                      valueDisplay:
                          isTime
                              ? '${config.maxSeconds}s'
                              : '${config.maxReps}',
                      onMinus: () {
                        if (isTime
                            ? config.maxSeconds > 5
                            : config.maxReps > 1) {
                          HapticFeedback.selectionClick();
                          setModalState(() {
                            if (isTime) {
                              config.maxSeconds -= 5;
                              if (config.minSeconds > config.maxSeconds)
                                config.minSeconds = config.maxSeconds;
                            } else {
                              config.maxReps--;
                              if (config.minReps > config.maxReps)
                                config.minReps = config.maxReps;
                            }
                          });
                          onChanged();
                        }
                      },
                      onPlus: () {
                        if (isTime
                            ? config.maxSeconds < 300
                            : config.maxReps < 50) {
                          HapticFeedback.selectionClick();
                          setModalState(() {
                            isTime ? config.maxSeconds += 5 : config.maxReps++;
                          });
                          onChanged();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recupero Rapido
              const Text(
                'Tempo di Recupero',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children:
                      [30, 45, 60, 90, 120, 180].map((sec) {
                        final isSel = config.restSeconds == sec;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => config.restSeconds = sec);
                            onChanged();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSel
                                      ? const Color(0xFFFF9700)
                                      : const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    isSel ? Colors.transparent : Colors.white12,
                              ),
                            ),
                            child: Text(
                              '${sec}s',
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Conferma',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _buildEditorRow({
    required String label,
    required String valueDisplay,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.remove_rounded,
                  color: Colors.white54,
                  size: 22,
                ),
                onPressed: onMinus,
              ),
              Text(
                valueDisplay,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFFFF9700),
                  size: 22,
                ),
                onPressed: onPlus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
