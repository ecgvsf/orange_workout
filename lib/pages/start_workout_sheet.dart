import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/routine_template.dart';
import '../pages/workout_engine_screen.dart';
import '../pages/select_free_exercise_screen.dart'; // <-- IMPORTA LA NUOVA PAGINA

class StartWorkoutSheet extends StatefulWidget {
  final Isar isar;
  final DateTime? workoutDate;

  const StartWorkoutSheet({super.key, required this.isar, this.workoutDate});

  static Future<void> show(
    BuildContext context,
    Isar isar,
    DateTime? workoutDate,
  ) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 380),
        reverseDuration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic, // Discesa morbida senza scatti
      ),
      builder: (ctx) => StartWorkoutSheet(isar: isar, workoutDate: workoutDate),
    );
  }

  @override
  State<StartWorkoutSheet> createState() => _StartWorkoutSheetState();
}

class _StartWorkoutSheetState extends State<StartWorkoutSheet> {
  List<RoutineTemplate> _routines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final list = await widget.isar.routineTemplates.where().findAll();
    if (mounted) {
      setState(() {
        _routines = list;
        _isLoading = false;
      });
    }
  }

  void _startWithRoutine(RoutineTemplate routine) {
    HapticFeedback.heavyImpact();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => WorkoutEngineScreen(
              isar: widget.isar,
              selectedRoutine: routine,
              workoutDate: widget.workoutDate,
              initialExerciseName:
                  routine.exercises.isNotEmpty
                      ? routine.exercises.first.exerciseName
                      : null,
            ),
      ),
    );
  }

  // APRE LA NUOVA SCHERMATA COMPLETA PER SCEGLIERE L'ESERCIZIO
  void _openSelectFreeExercisePage() async {
    HapticFeedback.selectionClick();

    // 1. Prendi il navigator del contesto principale
    final navigator = Navigator.of(context, rootNavigator: true);

    // 2. Chiudi prima completamente il bottom sheet corrente
    navigator.pop();

    // 3. Apri la nuova pagina a schermo intero
    navigator.push(
      MaterialPageRoute(
        builder:
            (context) => SelectFreeExerciseScreen(
              isar: widget.isar,
              workoutDate: widget.workoutDate,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nuovo Allenamento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- AZIONE 1: ALLENAMENTO LIBERO ---
          InkWell(
            onTap: _openSelectFreeExercisePage, // <-- Chiama la nuova schermata
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF9700).withValues(alpha: 0.18),
                    const Color(0xFF141414),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFF9700).withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9700),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allenamento Libero',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Scegli il primo esercizio per iniziare',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFFF9700),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'OPPURE SCEGLI UNA DELLE TUE SCHEDE',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // --- AZIONE 2: LISTA ROUTINE ---
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF9700),
                      ),
                    )
                    : _routines.isEmpty
                    ? Center(
                      child: Text(
                        'Nessuna scheda creata.\nUsa la sezione Schede per aggiungerne una.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13,
                        ),
                      ),
                    )
                    : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _routines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final r = _routines[index];
                        final int totalSets = r.exercises.fold<int>(
                          0,
                          (sum, e) => sum + e.targetSets,
                        );

                        String? tag = r.macroSplit;
                        if (tag == null || tag.isEmpty) {
                          final uniqueMuscles =
                              r.exercises
                                  .map((e) => e.muscleGroup)
                                  .where((m) => m.isNotEmpty)
                                  .toSet()
                                  .take(2)
                                  .toList();
                          if (uniqueMuscles.isNotEmpty) {
                            tag = uniqueMuscles.join(' • ');
                          }
                        }

                        String exercisesPreview = '';
                        if (r.exercises.isNotEmpty) {
                          final firstThree =
                              r.exercises
                                  .take(4)
                                  .map((e) => e.exerciseName)
                                  .toList();
                          final int remaining =
                              r.exercises.length - firstThree.length;
                          exercisesPreview = firstThree.join(', ');
                          if (remaining > 0) {
                            exercisesPreview += ', +$remaining altri';
                          }
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFF9700,
                                                  ).withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  tag.toUpperCase(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFFFF9700),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (tag != null &&
                                                tag.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              const Text(
                                                '•',
                                                style: TextStyle(
                                                  color: Colors.white24,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${r.exercises.length} es.  •  $totalSets serie',
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () => _startWithRoutine(r),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF9700),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Inizia',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (exercisesPreview.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    exercisesPreview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
