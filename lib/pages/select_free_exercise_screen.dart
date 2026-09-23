import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/exercise.dart';
import 'workout_engine_screen.dart';
import '../widgets/exercise_filterable_list_view.dart';

class SelectFreeExerciseScreen extends StatefulWidget {
  final Isar isar;
  final DateTime? workoutDate;

  const SelectFreeExerciseScreen({
    super.key,
    required this.isar,
    this.workoutDate,
  });

  @override
  State<SelectFreeExerciseScreen> createState() =>
      _SelectFreeExerciseScreenState();
}

class _SelectFreeExerciseScreenState extends State<SelectFreeExerciseScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Exercise> _allExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final list = await widget.isar.exercises.where().sortByName().findAll();
    if (mounted) {
      setState(() {
        _allExercises = list;
        _isLoading = false;
      });
    }
  }

  void _handleBack() {
    // 1. Togli immediatamente il focus alla tastiera
    FocusScope.of(context).unfocus();
    // 2. Chiudi la schermata in modo sicuro dopo che il focus è rilasciato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _startWorkoutWithExercise(String exerciseName) {
    HapticFeedback.heavyImpact();
    FocusScope.of(context).unfocus();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => WorkoutEngineScreen(
              isar: widget.isar,
              selectedRoutine: null,
              initialExerciseName: exerciseName,
              workoutDate: widget.workoutDate,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _handleBack();
                      },
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      splashRadius: 22,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scegli Esercizio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLoading
                                ? 'Caricamento catalogo...'
                                : '${_allExercises.length} esercizi disponibili',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                      ),
                      onPressed: _handleBack,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              const Divider(color: Color(0xFFFF9700), thickness: 1, height: 1),
              const SizedBox(height: 12),

              Expanded(
                child: ExerciseFilterableListView(
                  isar: widget.isar,
                  searchHint: 'Cerca esercizio per iniziare...',
                  onExerciseTap:
                      (exercise) => _startWorkoutWithExercise(exercise.name),
                  trailingBuilder: (context, exercise, _) {
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFFFF9700),
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
