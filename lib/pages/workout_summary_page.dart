import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine_template.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../widgets/stats/muscle_heatmap_card.dart';
import '../widgets/custom_dialog.dart';
import '../models/routine_item.dart';
import '../models/exercise_type.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final Isar isar;
  final Session session;

  const WorkoutSummaryScreen({
    super.key,
    required this.isar,
    required this.session,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  BodyGender _userGender = BodyGender.male;

  bool _isLoading = true;
  int _totalDurationSeconds = 0;
  double _totalVolumeKg = 0.0;
  int _totalHardSets = 0;
  final List<_ExerciseSummaryItem> _exerciseSummaries = [];
  final Map<String, int> _sessionMuscleCounts = {};

  bool _isRoutineSaved = false;

  // Gestione RPE Sessione (Default: Livello 3 -> RPE 8)
  int _selectedExertionLevel = 3; // Scala 1..5
  final List<int> _rpeMapping = const [6, 7, 8, 9, 10];
  final List<String> _rpeLabels = const [
    'Leggero',
    'Moderato',
    'Impegnativo',
    'Molto Duro',
    'Massimale',
  ];
  final List<String> _rirLabels = const [
    '4+ RIR',
    '~3 RIR',
    '~2 RIR',
    '1 RIR',
    'Cedimento',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _calculateSessionStats();
    _animController.forward();
    HapticFeedback.heavyImpact();

    _loadGender();
  }

  Future<void> _loadGender() async {
    final prefs = await SharedPreferences.getInstance();
    final genderStr = prefs.getString('user_gender') ?? 'Maschio';
    _userGender = genderStr == 'Femmina' ? BodyGender.female : BodyGender.male;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _normalizeMuscleKey(String rawMuscle) {
    final lower = rawMuscle.toLowerCase().trim();
    if (lower.contains('petto') || lower.contains('chest')) return 'chest';
    if (lower.contains('dorso') ||
        lower.contains('back') ||
        lower.contains('lats'))
      return 'dorsali';
    if (lower.contains('spall') || lower.contains('deltoid')) return 'deltoidi';
    if (lower.contains('bicipit') || lower.contains('biceps'))
      return 'bicipiti';
    if (lower.contains('tricipit') || lower.contains('triceps'))
      return 'tricipiti';

    // Gestione specifica degli addominali per gli ID corretti dell'SVG
    if (lower.contains('obliqu') || lower.contains('obliques'))
      return 'addominali-laterali';
    if (lower.contains('addom') ||
        lower.contains('core') ||
        lower.contains('abs'))
      return 'addominali-centrali';

    if (lower.contains('quadricipit') || lower.contains('quad'))
      return 'quadricipiti';
    if (lower.contains('femorali') || lower.contains('hamstring'))
      return 'femorali';
    if (lower.contains('glute')) return 'glutei';
    if (lower.contains('polpacc') || lower.contains('calf')) return 'polpacci';
    if (lower.contains('trapez')) return 'trapezio';
    if (lower.contains('lomb')) return 'lombari';
    if (lower.contains('avambracc') || lower.contains('forearm'))
      return 'avambracci';

    // Nuovi distretti
    if (lower.contains('adduttor') || lower.contains('adductor'))
      return 'adduttori';
    if (lower.contains('abduttor') || lower.contains('abductor'))
      return 'abduttori';
    if (lower.contains('soleo') || lower.contains('soleus')) return 'soleo';

    return lower;
  }

  Future<void> _calculateSessionStats() async {
    final startTime = widget.session.startTime;
    final endTime = widget.session.endTime ?? DateTime.now();
    _totalDurationSeconds = max(0, endTime.difference(startTime).inSeconds);

    final sets =
        await widget.isar.workoutSets
            .filter()
            .session((q) => q.idEqualTo(widget.session.id))
            .findAll();

    final Map<String, List<WorkoutSet>> groupedByExercise = {};
    final Map<String, String> primaryMuscleByExercise = {};
    final Map<String, List<String>> secondaryMusclesByExercise = {};

    double volume = 0.0;
    int hardSets = 0;

    for (final s in sets) {
      await s.exercise.load();
      final ex = s.exercise.value;
      final exName = ex?.name ?? 'Esercizio';
      final primary = ex?.muscleGroup ?? 'Generale';
      final secondaries = ex?.secondaryMuscles ?? [];

      groupedByExercise.putIfAbsent(exName, () => []).add(s);
      primaryMuscleByExercise.putIfAbsent(exName, () => primary);
      secondaryMusclesByExercise.putIfAbsent(exName, () => secondaries);

      if (!s.isWarmup) {
        hardSets++;
        if (s.holdSeconds != null && s.holdSeconds! > 0) {
          if (s.weight > 0) {
            volume += (s.weight * (s.holdSeconds! / 3.0));
          }
        } else {
          final int reps = s.reps ?? 0;
          volume += (s.weight * reps);
        }
      }
    }

    _totalVolumeKg = volume;
    _totalHardSets = hardSets;

    _exerciseSummaries.clear();
    _sessionMuscleCounts.clear();

    groupedByExercise.forEach((name, setsList) {
      final primaryMuscle = primaryMuscleByExercise[name] ?? 'Generale';
      final secondaries = secondaryMusclesByExercise[name] ?? [];
      final activeSets = setsList.where((s) => !s.isWarmup).length;

      if (activeSets > 0) {
        final primaryKey = _normalizeMuscleKey(primaryMuscle);
        _sessionMuscleCounts[primaryKey] =
            (_sessionMuscleCounts[primaryKey] ?? 0) + activeSets;

        for (final sec in secondaries) {
          final secKey = _normalizeMuscleKey(sec);
          final int secondaryStimulus = (activeSets ~/ 2).clamp(1, activeSets);
          _sessionMuscleCounts[secKey] =
              (_sessionMuscleCounts[secKey] ?? 0) + secondaryStimulus;
        }
      }

      double maxWeight = 0.0;
      int bestValue = 0;
      bool isTimeBased = false;

      for (final s in setsList) {
        if (s.holdSeconds != null && s.holdSeconds! > 0) {
          isTimeBased = true;
          if (s.weight > maxWeight ||
              (s.weight == maxWeight && s.holdSeconds! > bestValue)) {
            maxWeight = s.weight;
            bestValue = s.holdSeconds!;
          }
        } else {
          final reps = s.reps ?? 0;
          if (s.weight > maxWeight ||
              (s.weight == maxWeight && reps > bestValue)) {
            maxWeight = s.weight;
            bestValue = reps;
          }
        }
      }

      final String bestSetString =
          isTimeBased
              ? (maxWeight > 0
                  ? '${maxWeight.toStringAsFixed(1)} kg × ${bestValue}s'
                  : '${bestValue}s')
              : (maxWeight > 0
                  ? '${maxWeight.toStringAsFixed(1)} kg × $bestValue'
                  : 'BW × $bestValue');

      _exerciseSummaries.add(
        _ExerciseSummaryItem(
          exerciseName: name,
          muscleGroup: primaryMuscle,
          setsCount: setsList.length,
          bestSetString: bestSetString,
          sets: setsList,
        ),
      );
    });

    // Imposta l'RPE iniziale in base al primo set registrato se già valorizzato
    if (sets.isNotEmpty && sets.first.rpe != null) {
      final existingRpe = sets.first.rpe!;
      final idx = _rpeMapping.indexOf(existingRpe);
      if (idx != -1) {
        _selectedExertionLevel = idx + 1;
      }
    } else {
      // Salva l'RPE di default (8) su tutti i set
      _updateSessionSetsRpe(_rpeMapping[_selectedExertionLevel - 1]);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSessionSetsRpe(int rpeValue) async {
    final sets =
        await widget.isar.workoutSets
            .filter()
            .session((q) => q.idEqualTo(widget.session.id))
            .findAll();

    await widget.isar.writeTxn(() async {
      for (final s in sets) {
        s.rpe = rpeValue;
        await widget.isar.workoutSets.put(s);
      }
    });
  }

  void _onRpeLevelSelected(int level) {
    HapticFeedback.selectionClick();
    setState(() => _selectedExertionLevel = level);
    final mappedRpe = _rpeMapping[level - 1];
    _updateSessionSetsRpe(mappedRpe);
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '${h}h ${remM}m';
    }
    return '$m min ${s > 0 ? '$s s' : ''}';
  }

  Future<void> _showCreateRoutineModal() async {
    final TextEditingController nameController = TextEditingController(
      text:
          'Scheda del ${widget.session.date.day}/${widget.session.date.month}',
    );
    final TextEditingController notesController = TextEditingController();

    // Split predefinito e lista dei target principali
    String selectedMacroSplit = 'Push';
    const List<String> macroSplits = [
      'Push',
      'Pull',
      'Legs',
      'Upper',
      'Lower',
      'Full Body',
    ];

    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Maniglietta Drag superiore
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header del Modale
                    const Row(
                      children: [
                        Icon(
                          Icons.bookmark_add_rounded,
                          color: Color(0xFFFF9700),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Crea Scheda da questo Workout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Configura nome, target muscolare e note per salvare questi esercizi come routine nel tuo mesociclo.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 18),

                    // 1. Campo Nome Scheda
                    TextField(
                      controller: nameController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nome Scheda',
                        labelStyle: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontSize: 13,
                        ),
                        hintText: 'es. Upper A - Focus Petto & Dorso',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF141414),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF9700),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Selettore Macro-Target (Split)
                    const Text(
                      'TARGET PRINCIPALE (SPLIT)',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: macroSplits.length,
                        itemBuilder: (context, idx) {
                          final split = macroSplits[idx];
                          final isSelected = split == selectedMacroSplit;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() => selectedMacroSplit = split);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFFFF9700)
                                        : const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Colors.transparent
                                          : Colors.white12,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  split,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Campo Note Tecniche / Focus
                    TextField(
                      controller: notesController,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Note Tecniche o Obiettivi (Opzionale)',
                        labelStyle: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        hintText:
                            'es. Progressione carico su panca, recupero 90s...',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFFFF9700),
                          size: 22,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF141414),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF9700),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // 4. Pulsanti di Azione
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Annulla',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                await AppDialog.show(
                                  ctx,
                                  type: AppDialogType.error,
                                  title: 'Nome Mancante',
                                  message:
                                      'Inserisci un nome per la scheda prima di salvarla.',
                                  primaryButtonText: 'Ho capito',
                                );
                                return;
                              }

                              final routineConfigList =
                                  <RoutineExerciseConfig>[];

                              for (final item in _exerciseSummaries) {
                                final isTimed = item.sets.any(
                                  (s) =>
                                      s.holdSeconds != null &&
                                      s.holdSeconds! > 0,
                                );

                                if (isTimed) {
                                  // Calcolo media dei secondi per esercizi isometrici
                                  int avgSeconds = 30;
                                  final timedSets = item.sets.where(
                                    (s) => s.holdSeconds != null,
                                  );
                                  if (timedSets.isNotEmpty) {
                                    final totalSecs = timedSets.fold<int>(
                                      0,
                                      (sum, s) => sum + (s.holdSeconds ?? 30),
                                    );
                                    avgSeconds = (totalSecs / timedSets.length)
                                        .round()
                                        .clamp(5, 300);
                                  }

                                  routineConfigList.add(
                                    RoutineExerciseConfig()
                                      ..exerciseName = item.exerciseName
                                      ..muscleGroup = item.muscleGroup
                                      ..exerciseType = ExerciseType.time
                                      ..targetSets = item.setsCount
                                      ..minSeconds = max(5, avgSeconds - 5)
                                      ..maxSeconds = avgSeconds + 5
                                      ..minReps = 0
                                      ..maxReps = 0
                                      ..targetRpe = 8.0
                                      ..restSeconds = 60,
                                  );
                                } else {
                                  // Calcolo media ripetizioni per esercizi standard
                                  int avgReps = 8;
                                  final repSets = item.sets.where(
                                    (s) => s.reps != null,
                                  );
                                  if (repSets.isNotEmpty) {
                                    final totalReps = repSets.fold<int>(
                                      0,
                                      (sum, s) => sum + (s.reps ?? 8),
                                    );
                                    avgReps = (totalReps / repSets.length)
                                        .round()
                                        .clamp(1, 100);
                                  }

                                  routineConfigList.add(
                                    RoutineExerciseConfig()
                                      ..exerciseName = item.exerciseName
                                      ..muscleGroup = item.muscleGroup
                                      ..exerciseType = ExerciseType.reps
                                      ..targetSets = item.setsCount
                                      ..minReps = max(1, avgReps - 2)
                                      ..maxReps = avgReps + 2
                                      ..minSeconds = 0
                                      ..maxSeconds = 0
                                      ..targetRpe = 8.0
                                      ..restSeconds = 90,
                                  );
                                }
                              }

                              final newRoutine =
                                  RoutineTemplate()
                                    ..name = name
                                    ..macroSplit = selectedMacroSplit
                                    ..notes =
                                        notesController.text.trim().isNotEmpty
                                            ? notesController.text.trim()
                                            : null
                                    ..exercises = routineConfigList;

                              await widget.isar.writeTxn(() async {
                                await widget.isar.routineTemplates.put(
                                  newRoutine,
                                );
                                widget.session.routine.value = newRoutine;
                                await widget.session.routine.save();
                              });

                              if (ctx.mounted) Navigator.pop(ctx, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9700),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Salva Scheda',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      setState(() => _isRoutineSaved = true);
      await AppDialog.show(
        context,
        type: AppDialogType.success,
        title: 'Scheda Creata!',
        message:
            'La routine "${nameController.text.trim()}" con target $selectedMacroSplit è stata salvata con successo.',
        primaryButtonText: 'Ottimo',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.session.routine.loadSync();

    final isFreeWorkout =
        widget.session.routine.value == null && !_isRoutineSaved;
    final routineTitle =
        widget.session.routine.value?.name ?? 'Allenamento Libero';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF9700)),
                )
                : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildCelebrationHero(routineTitle),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // --- KPI ROW ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              icon: Icons.timer_outlined,
                              label: 'DURATA',
                              value: _formatDuration(_totalDurationSeconds),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatBox(
                              icon: Icons.fitness_center_rounded,
                              label: 'VOLUME',
                              value: '${_totalVolumeKg.toInt()} kg',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatBox(
                              icon: Icons.local_fire_department_rounded,
                              label: 'HARD SETS',
                              value: '$_totalHardSets set',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- MINI FORM RPE (FATICA PERCEPITA) ---
                      _buildRpeSelectorCard(),
                      const SizedBox(height: 16),

                      // --- HEATMAP MUSCOLARE ---
                      SizedBox(
                        height: 250,
                        child: MuscleHeatmapCard(
                          title: 'Focus Muscolare Sessione',
                          weeklyWorkouts: _sessionMuscleCounts,
                          initialGender: _userGender,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- OPZIONE CREA SCHEDA ---
                      if (isFreeWorkout) ...[
                        _buildCreateRoutinePromptCard(),
                        const SizedBox(height: 16),
                      ],

                      // --- LISTA ESERCIZI ---
                      const Text(
                        'ESERCIZI COMPLETATI',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _exerciseSummaries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final ex = _exerciseSummaries[index];
                          return _buildExerciseRow(ex);
                        },
                      ),
                      const SizedBox(height: 24),

                      // --- PULSANTE DI CHIUSURA ---
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9700),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: const Text(
                          'CHIUDI E TORNA ALLA HOME',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildRpeSelectorCard() {
    final currentRpe = _rpeMapping[_selectedExertionLevel - 1];
    final currentLabel = _rpeLabels[_selectedExertionLevel - 1];
    final currentRir = _rirLabels[_selectedExertionLevel - 1];

    Color activeColor;
    if (_selectedExertionLevel <= 2) {
      activeColor = const Color(0xFFFFB74D); // Giallo-arancio
    } else if (_selectedExertionLevel == 3) {
      activeColor = const Color(0xFFFF9700); // Arancione target
    } else {
      activeColor = const Color(0xFFFF5252); // Rosso fatica alta
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_rounded, color: activeColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'SFORZO PERCEPITO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: activeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'RPE $currentRpe • $currentLabel ($currentRir)',
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Seleziona il livello di fatica per calibrare l\'RPE di tutte le serie registrate:',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 14),

          // Riga dei 5 pulsanti
          Row(
            children: List.generate(5, (index) {
              final level = index + 1;
              final isSelected = _selectedExertionLevel == level;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == 4 ? 0 : 4,
                  ),
                  child: InkWell(
                    onTap: () => _onRpeLevelSelected(level),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? activeColor : const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? activeColor
                                  : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                                : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$level',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'RPE ${_rpeMapping[index]}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '← Poco faticoso',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text(
                'Massimale / Cedimento →',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationHero(String routineTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF9700).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9700).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF9700).withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFF9700),
              size: 36,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'OTTIMO LAVORO!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            routineTitle,
            style: const TextStyle(
              color: Color(0xFFFFB74D),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFF9700), size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRoutinePromptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1610),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF9700).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9700).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmark_add_rounded,
              color: Color(0xFFFF9700),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ti è piaciuta la sessione?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Salva questi ${_exerciseSummaries.length} esercizi come nuova scheda.',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _showCreateRoutineModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9700),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'SALVA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(_ExerciseSummaryItem ex) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${ex.muscleGroup.toUpperCase()} • Miglior set: ${ex.bestSetString}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${ex.setsCount} set',
              style: const TextStyle(
                color: Color(0xFFFF9700),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSummaryItem {
  final String exerciseName;
  final String muscleGroup;
  final int setsCount;
  final String bestSetString;
  final List<WorkoutSet> sets;

  _ExerciseSummaryItem({
    required this.exerciseName,
    required this.muscleGroup,
    required this.setsCount,
    required this.bestSetString,
    required this.sets,
  });
}
