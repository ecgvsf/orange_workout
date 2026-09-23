import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/exercise_type.dart';
import '../../utils/time_formatters.dart';
import '../../utils/weight_converter.dart';

class ActiveExerciseCard extends StatefulWidget {
  final String exerciseName;
  final String muscleGroup;
  final int targetSets;
  final int minReps;
  final int maxReps;
  final double weight;
  final int reps;
  final bool isWarmup;
  final int currentSetNumber;
  final VoidCallback onSwap;
  final VoidCallback onWeightMinus;
  final VoidCallback onWeightPlus;
  final VoidCallback onRepsMinus;
  final VoidCallback onRepsPlus;
  final ValueChanged<double> onWeightChanged; // <-- Callback digitazione peso
  final ValueChanged<int> onRepsChanged; // <-- Callback digitazione reps
  final ValueChanged<int>
  onHoldSecondsChanged; // <-- Callback digitazione tempo
  final ValueChanged<bool?> onWarmupChanged;
  final VoidCallback onRegisterSet;
  final ExerciseType exerciseType;
  final int holdSeconds;
  final VoidCallback onHoldSecondsMinus;
  final VoidCallback onHoldSecondsPlus;

  // Gestione unità di misura
  final WeightUnit weightUnit;
  final ValueChanged<WeightUnit> onUnitChanged;

  const ActiveExerciseCard({
    super.key,
    required this.exerciseName,
    required this.muscleGroup,
    required this.targetSets,
    required this.minReps,
    required this.maxReps,
    required this.weight,
    required this.reps,
    required this.isWarmup,
    required this.currentSetNumber,
    required this.onSwap,
    required this.onWeightMinus,
    required this.onWeightPlus,
    required this.onRepsMinus,
    required this.onRepsPlus,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onHoldSecondsChanged,
    required this.onWarmupChanged,
    required this.onRegisterSet,
    required this.exerciseType,
    required this.holdSeconds,
    required this.onHoldSecondsMinus,
    required this.onHoldSecondsPlus,
    required this.weightUnit,
    required this.onUnitChanged,
  });

  @override
  State<ActiveExerciseCard> createState() => _ActiveExerciseCardState();
}

class _ActiveExerciseCardState extends State<ActiveExerciseCard> {
  late final TextEditingController _weightController;
  late final TextEditingController _rightFieldController;
  late final FocusNode _weightFocusNode;
  late final FocusNode _rightFocusNode;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.weight.toStringAsFixed(1),
    );
    _rightFieldController = TextEditingController(
      text:
          widget.exerciseType == ExerciseType.time
              ? '${widget.holdSeconds}'
              : '${widget.reps}',
    );
    _weightFocusNode = FocusNode();
    _rightFocusNode = FocusNode();

    // Riformatta quando si perde il focus
    _weightFocusNode.addListener(() {
      if (!_weightFocusNode.hasFocus) {
        final parsed =
            double.tryParse(_weightController.text.replaceAll(',', '.')) ??
            widget.weight;
        _weightController.text = parsed.toStringAsFixed(1);
        widget.onWeightChanged(parsed);
      }
    });

    _rightFocusNode.addListener(() {
      if (!_rightFocusNode.hasFocus) {
        final parsed =
            int.tryParse(_rightFieldController.text) ??
            (widget.exerciseType == ExerciseType.time
                ? widget.holdSeconds
                : widget.reps);
        _rightFieldController.text = '$parsed';
        if (widget.exerciseType == ExerciseType.time) {
          widget.onHoldSecondsChanged(parsed);
        } else {
          widget.onRepsChanged(parsed);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ActiveExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronizza i controller solo se l'utente non sta digitando attivamente
    if (!_weightFocusNode.hasFocus && oldWidget.weight != widget.weight) {
      _weightController.text = widget.weight.toStringAsFixed(1);
    }

    final isTime = widget.exerciseType == ExerciseType.time;
    if (!_rightFocusNode.hasFocus) {
      if (isTime && oldWidget.holdSeconds != widget.holdSeconds) {
        _rightFieldController.text = '${widget.holdSeconds}';
      } else if (!isTime && oldWidget.reps != widget.reps) {
        _rightFieldController.text = '${widget.reps}';
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _rightFieldController.dispose();
    _weightFocusNode.dispose();
    _rightFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTime = widget.exerciseType == ExerciseType.time;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER: NOME ESERCIZIO & CAMBIA ESERCIZIO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFFFF9700),
                ),
                tooltip: 'Cambia Esercizio',
                onPressed: widget.onSwap,
              ),
            ],
          ),

          // 2. BADGE MUSCOLO & TARGET
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.muscleGroup.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFFB74D),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isTime
                    ? 'Target: ${widget.targetSets} set × ${formatTimeSeconds(widget.minReps)} - ${formatTimeSeconds(widget.maxReps)}'
                    : 'Target: ${widget.targetSets} set × ${widget.minReps}-${widget.maxReps} reps',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. I DUE CONTATORI AFFIANCATI CON PARI ALTEZZA (IntrinsicHeight)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CARD SINISTRA: PESO
                Expanded(
                  child: _buildCounterContainer(
                    header: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CARICO',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        _buildWeightUnitToggle(),
                      ],
                    ),
                    controller: _weightController,
                    focusNode: _weightFocusNode,
                    isDecimal: true,
                    onMinus: widget.onWeightMinus,
                    onPlus: widget.onWeightPlus,
                    onSubmitted: (val) {
                      final parsed =
                          double.tryParse(val.replaceAll(',', '.')) ??
                          widget.weight;
                      widget.onWeightChanged(parsed);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // CARD DESTRA: RIPETIZIONI O TEMPO IN SECONDI
                Expanded(
                  child: _buildCounterContainer(
                    header: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTime ? 'DURATA (SEC)' : 'RIPETIZIONI',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            isTime ? 'SEC' : 'REPS',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    controller: _rightFieldController,
                    focusNode: _rightFocusNode,
                    isDecimal: false,
                    onMinus:
                        isTime ? widget.onHoldSecondsMinus : widget.onRepsMinus,
                    onPlus:
                        isTime ? widget.onHoldSecondsPlus : widget.onRepsPlus,
                    onSubmitted: (val) {
                      final parsed =
                          int.tryParse(val) ??
                          (isTime ? widget.holdSeconds : widget.reps);
                      if (isTime) {
                        widget.onHoldSecondsChanged(parsed);
                      } else {
                        widget.onRepsChanged(parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. CHECKBOX WARMUP
          Row(
            children: [
              Checkbox(
                value: widget.isWarmup,
                activeColor: const Color(0xFFFF9700),
                onChanged: widget.onWarmupChanged,
              ),
              const Text(
                'Serie di Riscaldamento (Warmup)',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 5. REGISTRA SERIE
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onRegisterSet,
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(
                'REGISTRA SERIE ${widget.currentSetNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9700),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Toggle KG / LBS compatto
  Widget _buildWeightUnitToggle() {
    final bool isLbs = widget.weightUnit == WeightUnit.lbs;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitPill(
            label: 'KG',
            isActive: !isLbs,
            onTap: () {
              if (isLbs) {
                HapticFeedback.selectionClick();
                widget.onUnitChanged(WeightUnit.kg);
              }
            },
          ),
          _buildUnitPill(
            label: 'LBS',
            isActive: isLbs,
            onTap: () {
              if (!isLbs) {
                HapticFeedback.selectionClick();
                widget.onUnitChanged(WeightUnit.lbs);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnitPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF9700) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Card contatore con testo digitabile "invisibile"
  Widget _buildCounterContainer({
    required Widget header,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isDecimal,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required ValueChanged<String> onSubmitted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          header,
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_rounded,
                  color: Colors.white60,
                  size: 24,
                ),
                onPressed: () {
                  focusNode.unfocus();
                  onMinus();
                },
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: isDecimal,
                  ),
                  textAlign: TextAlign.center,
                  cursorColor: const Color(0xFFFF9700),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                  onSubmitted: onSubmitted,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFFFF9700),
                  size: 24,
                ),
                onPressed: () {
                  focusNode.unfocus();
                  onPlus();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
