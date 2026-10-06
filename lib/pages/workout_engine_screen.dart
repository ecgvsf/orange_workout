import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine_template.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../models/exercise_type.dart';
import '../services/workout_notification_service.dart';
import '../services/apple_live_activity.dart';
import '../utils/weight_converter.dart';
import '../widgets/exercise_filterable_list_view.dart';
import '../widgets/workout_engine/workout_header.dart';
import '../widgets/workout_engine/workout_rest_timer_card.dart';
import '../widgets/workout_engine/active_exercise_card.dart';
import '../widgets/workout_engine/completed_exercise_row.dart';
import '../pages/workout_summary_page.dart';
import '../services/native_timer_chip_service.dart';

const MethodChannel _islandChannel = MethodChannel(
  'com.orange_workout/dynamic_island',
);

class CompletedExerciseSummary {
  final String exerciseName;
  final String muscleGroup;
  final List<WorkoutSet> sets;

  CompletedExerciseSummary({
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
  });
}

class WorkoutEngineScreen extends StatefulWidget {
  final Isar isar;
  final RoutineTemplate? selectedRoutine;
  final String? initialExerciseName;
  final DateTime? workoutDate;

  const WorkoutEngineScreen({
    super.key,
    required this.isar,
    this.selectedRoutine,
    this.initialExerciseName,
    this.workoutDate,
  });

  @override
  State<WorkoutEngineScreen> createState() => _WorkoutEngineScreenState();
}

// Implementato WidgetsBindingObserver per rilevare il risveglio dallo sfondo/blocco
class _WorkoutEngineScreenState extends State<WorkoutEngineScreen>
    with WidgetsBindingObserver {
  // Timer di sessione
  late final DateTime _startTime;
  int _elapsedSeconds = 0;
  Timer? _sessionTimer;

  // Timer di recupero basato su timestamp reale
  int _restRemaining = 0;
  int _initialRestDuration = 90;
  DateTime? _restEndTime; // Timestamp assoluto di termine recupero
  Timer? _restTimer;

  // Live Activity (iOS)
  String? _activeLiveActivityId;

  // Preferenze Globali
  WeightUnit _activeUnit = WeightUnit.kg;
  double _globalMinWeightIncrement = 2.5;

  // Stato dell'esercizio corrente
  int _currentRoutineIndex = 0;
  String _currentExerciseName = 'Caricamento...';
  String _currentMuscleGroup = 'Generale';
  int _targetSets = 3;
  int _minReps = 8;
  int _maxReps = 10;
  int _restSeconds = 90;

  ExerciseType _activeExerciseType = ExerciseType.reps;
  int _currentHoldSeconds = 30;

  // Parametri del set
  double _currentWeight = 60.0;
  int _currentReps = 8;
  bool _isWarmup = false;

  final List<WorkoutSet> _activeExerciseSets = [];
  final Map<String, List<WorkoutSet>> _pausedExercises = {};
  final List<CompletedExerciseSummary> _completedExercises = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTime = DateTime.now();
    _startSessionTimer();

    _islandChannel.setMethodCallHandler((call) async {
      if (call.method == "addTime") {
        final int addedSecs = call.arguments as int;
        _addRestTimeFromIsland(addedSecs);
      }
    });

    _checkDynamicIslandPermissions();

    // Inizializzazione sincrona immediata prima del primo frame
    if (widget.selectedRoutine != null &&
        widget.selectedRoutine!.exercises.isNotEmpty) {
      _currentExerciseName = widget.selectedRoutine!.exercises[0].exerciseName;
      _currentMuscleGroup = widget.selectedRoutine!.exercises[0].muscleGroup;
    } else if (widget.initialExerciseName != null) {
      _currentExerciseName = widget.initialExerciseName!;
    } else {
      _currentExerciseName = 'Esercizio Libero';
    }

    WorkoutNotificationService().onAddTimeListener = (extraSeconds) {
      if (!mounted) return;
      _onNotificationAddedTime(extraSeconds);
    };
    _loadGlobalPreferences().then((_) {
      _initializeExercise();
    });
  }

  Future _checkDynamicIslandPermissions() async {
    if (!Platform.isAndroid) return;

    final bool isEnabled = await _islandChannel.invokeMethod('checkPermission');
    if (!isEnabled && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text(
                'Dynamic Island',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Per mostrare la pillola col timer quando esci dall\'app, attiva il servizio di Accessibilità per Orange Workout nelle impostazioni.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Ignora',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9700),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _islandChannel.invokeMethod('openSettings');
                  },
                  child: const Text(
                    'Impostazioni',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
    }
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAllTimers();
      if (Platform.isAndroid) {
        _islandChannel.invokeMethod('hideIsland'); // Nasconde la pillola in app
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (Platform.isAndroid && _restRemaining > 0) {
        // Mostra la pillola solo se esci dall'app e il timer è attivo
        _islandChannel.invokeMethod('showIsland', {'seconds': _restRemaining});
      }
    }
  }

  void _addRestTimeFromIsland(int extraSeconds) {
    if (_restRemaining <= 0 && _restEndTime == null) return;
    final now = DateTime.now();
    final baseTime =
        (_restEndTime != null && _restEndTime!.isAfter(now))
            ? _restEndTime!
            : now;

    setState(() {
      _restEndTime = baseTime.add(Duration(seconds: extraSeconds));
      _restRemaining = _restEndTime!.difference(now).inSeconds;
      _initialRestDuration += extraSeconds;
    });
  }

  /// Sincronizza sia la durata totale della sessione sia il conto alla rovescia di recupero
  void _syncAllTimers() {
    if (!mounted) return;

    setState(() {
      // 1. Sincronizzazione timer sessione
      _elapsedSeconds = DateTime.now().difference(_startTime).inSeconds;

      // 2. Sincronizzazione timer recupero
      if (_restEndTime != null) {
        final remaining = _restEndTime!.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          _onRestCompleted();
        } else {
          _restRemaining = remaining;
        }
      }
    });
  }

  Future _loadGlobalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final savedUnit = prefs.getString('global_weight_unit') ?? 'kg';
        _activeUnit = savedUnit == 'lbs' ? WeightUnit.lbs : WeightUnit.kg;
        _globalMinWeightIncrement =
            prefs.getDouble('global_weight_increment') ?? 2.5;
        _restSeconds = prefs.getInt('global_rest_time') ?? 90;
      });
    }
  }

  /// Metodo chiamato dal pulsante della notifica (+15s / +30s)
  void _onNotificationAddedTime(int extraSeconds) {
    if (_restRemaining <= 0 && _restEndTime == null) return;

    final now = DateTime.now();
    final baseTime =
        (_restEndTime != null && _restEndTime!.isAfter(now))
            ? _restEndTime!
            : now;

    final newEndTime = baseTime.add(Duration(seconds: extraSeconds));
    final updatedRemaining = newEndTime.difference(now).inSeconds;

    setState(() {
      _restEndTime = newEndTime;
      _restRemaining = updatedRemaining;
      _initialRestDuration += extraSeconds;
    });

    // Se su iOS è attiva una Live Activity, la aggiorniamo
    if (Platform.isIOS) {
      AppleLiveActivityService.startRestActivity(
        exerciseName: _currentExerciseName,
        seconds: _restRemaining,
      ).then((id) => _activeLiveActivityId = id);
    }
  }

  /// Metodo chiamato dai pulsanti a schermo (+15s / +30s nella WorkoutRestTimerCard)
  void _addRestTime(int extraSeconds) {
    if (_restRemaining <= 0 && _restEndTime == null) return;

    final now = DateTime.now();
    final baseTime =
        (_restEndTime != null && _restEndTime!.isAfter(now))
            ? _restEndTime!
            : now;

    final newEndTime = baseTime.add(Duration(seconds: extraSeconds));
    final updatedRemaining = newEndTime.difference(now).inSeconds;

    setState(() {
      _restEndTime = newEndTime;
      _restRemaining = updatedRemaining;
      _initialRestDuration += extraSeconds;
    });

    // Riavvia/aggiorna la notifica con i pulsanti e il nuovo timestamp
    WorkoutNotificationService().startRestNotification(
      seconds: _restRemaining,
      exerciseName: _currentExerciseName,
    );

    if (Platform.isIOS) {
      AppleLiveActivityService.startRestActivity(
        exerciseName: _currentExerciseName,
        seconds: _restRemaining,
      ).then((id) => _activeLiveActivityId = id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    WorkoutNotificationService().onAddTimeListener = null;
    WorkoutNotificationService().cancelRestNotifications();
    if (Platform.isIOS && _activeLiveActivityId != null) {
      AppleLiveActivityService.stopActivity(_activeLiveActivityId!);
    }
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Calcolo differenziale continuo per evitare drifting temporale
          _elapsedSeconds = DateTime.now().difference(_startTime).inSeconds;
        });
      }
    });
  }

  // --- LOGICA TIMER DI RECUPERO A DIFFERENZA ORARIA ---
  Future _startRestCountdown(int seconds) async {
    _restTimer?.cancel();
    final now = DateTime.now();

    setState(() {
      _initialRestDuration = seconds;
      _restRemaining = seconds;
      _restEndTime = now.add(Duration(seconds: seconds));
    });

    if (Platform.isAndroid) {
      // Crea SOLO la notifica silenziosa (nessuna pillola finché non esci dall'app)
      _islandChannel.invokeMethod('startSilentNotification', {
        'exerciseName': _currentExerciseName,
      });
    } else if (Platform.isIOS) {
      if (_activeLiveActivityId != null) {
        await AppleLiveActivityService.stopActivity(_activeLiveActivityId!);
        _activeLiveActivityId = null;
      }
      _activeLiveActivityId = await AppleLiveActivityService.startRestActivity(
        exerciseName: _currentExerciseName,
        seconds: seconds,
      );
    }

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _restEndTime == null) {
        timer.cancel();
        return;
      }

      final remaining = _restEndTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
        timer.cancel();
        _onRestCompleted();
      } else {
        setState(() {
          _restRemaining = remaining;
        });
      }
    });

    // Notifica di sistema per Android / iOS (Singola notifica unificata)
    WorkoutNotificationService().startRestNotification(
      seconds: seconds,
      exerciseName: _currentExerciseName,
    );
  }

  void _onRestCompleted() {
    _restTimer?.cancel();
    _restEndTime = null;
    HapticFeedback.heavyImpact();

    WorkoutNotificationService().cancelRestNotifications();
    WorkoutNotificationService().triggerInstantAlarm(_currentExerciseName);

    if (Platform.isIOS && _activeLiveActivityId != null) {
      AppleLiveActivityService.stopActivity(_activeLiveActivityId!);
      _activeLiveActivityId = null;
    }

    if (mounted) {
      setState(() {
        _restRemaining = 0;
      });
    }
  }

  void _skipRest() async {
    _restTimer?.cancel();
    _restEndTime = null;
    await WorkoutNotificationService().cancelRestNotifications();
    if (Platform.isAndroid) {
      await _islandChannel.invokeMethod('stopIsland');
    } else if (Platform.isIOS && _activeLiveActivityId != null) {
      await AppleLiveActivityService.stopActivity(_activeLiveActivityId!);
      _activeLiveActivityId = null;
    }
    setState(() {
      _restRemaining = 0;
    });
  }

  // --- CARICAMENTO ESERCIZIO & GHOST DATA ---
  Future _initializeExercise() async {
    if (widget.selectedRoutine != null &&
        widget.selectedRoutine!.exercises.isNotEmpty) {
      final config = widget.selectedRoutine!.exercises[_currentRoutineIndex];
      _activeExerciseType = config.exerciseType;
      _currentExerciseName = config.exerciseName;
      _currentMuscleGroup = config.muscleGroup;
      _targetSets = config.targetSets;
      _minReps = config.minReps;
      _maxReps = config.maxReps;
      _restSeconds = config.restSeconds;
      _currentReps = config.minReps;
    } else {
      _currentExerciseName = widget.initialExerciseName ?? 'Esercizio Libero';
      final ex =
          await widget.isar.exercises
              .filter()
              .nameEqualTo(_currentExerciseName)
              .findFirst();
      if (ex != null) {
        _currentMuscleGroup = ex.muscleGroup;
        _activeExerciseType = ex.exerciseType;
      }
    }

    await _loadGhostDataFor(_currentExerciseName);
  }

  Future _loadGhostDataFor(String exerciseName) async {
    final matchingSets =
        await widget.isar.workoutSets
            .filter()
            .exercise((q) => q.nameEqualTo(exerciseName))
            .findAll();

    if (matchingSets.isNotEmpty && mounted) {
      matchingSets.sort((a, b) => a.id.compareTo(b.id));
      final lastSet = matchingSets.last;

      setState(() {
        _currentWeight = lastSet.weight;
        _currentReps = lastSet.reps ?? 8;
      });
    }
  }

  void _toggleWeightUnit(WeightUnit newUnit) {
    if (newUnit == _activeUnit) return;
    setState(() {
      if (newUnit == WeightUnit.lbs) {
        _currentWeight = WeightConverter.toDisplay(
          _currentWeight,
          WeightUnit.lbs,
        );
      } else {
        _currentWeight = WeightConverter.toDatabaseKg(
          _currentWeight,
          WeightUnit.lbs,
        );
      }
      _currentWeight = double.parse(_currentWeight.toStringAsFixed(1));
      _activeUnit = newUnit;
    });
  }

  void _completeCurrentSet() {
    final double normalizedKg = WeightConverter.toDatabaseKg(
      _currentWeight,
      _activeUnit,
    );

    final set =
        WorkoutSet()
          ..weight = double.parse(normalizedKg.toStringAsFixed(2))
          ..reps =
              _activeExerciseType == ExerciseType.reps ? _currentReps : null
          ..holdSeconds =
              _activeExerciseType == ExerciseType.time
                  ? _currentHoldSeconds
                  : null
          ..isWarmup = _isWarmup
          ..rpe = 8;

    setState(() {
      _activeExerciseSets.add(set);
    });

    _startRestCountdown(_restSeconds);
  }

  void _removeActiveSet(int index) {
    setState(() {
      _activeExerciseSets.removeAt(index);
    });
  }

  void _removeCompletedExercise(int index) {
    final exerciseName = _completedExercises[index].exerciseName;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Elimina Esercizio Concluso',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Sei sicuro di voler rimuovere tutte le serie registrate per $exerciseName?',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Annulla',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _completedExercises.removeAt(index);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Elimina',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _finishCurrentExercise() {
    if (_activeExerciseSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registra almeno una serie prima di completare.'),
          backgroundColor: Color(0xFF262626),
        ),
      );
      return;
    }

    _completedExercises.add(
      CompletedExerciseSummary(
        exerciseName: _currentExerciseName,
        muscleGroup: _currentMuscleGroup,
        sets: List.from(_activeExerciseSets),
      ),
    );
    _activeExerciseSets.clear();

    if (widget.selectedRoutine != null &&
        _currentRoutineIndex + 1 < widget.selectedRoutine!.exercises.length) {
      setState(() {
        _currentRoutineIndex++;
      });
      _initializeExercise();
    } else {
      _openQuickExercisePicker();
    }
  }

  void _onSwapExercisePressed() {
    if (_activeExerciseSets.isNotEmpty) {
      if (_pausedExercises.containsKey(_currentExerciseName)) {
        _pausedExercises[_currentExerciseName]!.addAll(_activeExerciseSets);
      } else {
        _pausedExercises[_currentExerciseName] = List.from(_activeExerciseSets);
      }
      _activeExerciseSets.clear();
    }

    _openQuickExercisePicker();
  }

  void _openQuickExercisePicker() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Scegli Esercizio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ExerciseFilterableListView(
                  isar: widget.isar,
                  searchHint: 'Cerca esercizio...',
                  onExerciseTap: (exercise) {
                    Navigator.pop(ctx);
                    setState(() {
                      _currentExerciseName = exercise.name;
                      _currentMuscleGroup = exercise.muscleGroup;
                      _activeExerciseType = exercise.exerciseType;
                      _targetSets = 3;
                      if (exercise.exerciseType == ExerciseType.time) {
                        _minReps = 30;
                        _maxReps = 60;
                      } else {
                        _minReps = 8;
                        _maxReps = 12;
                      }

                      if (_pausedExercises.containsKey(exercise.name)) {
                        _activeExerciseSets.addAll(
                          _pausedExercises.remove(exercise.name)!,
                        );
                      }
                    });
                    _loadGhostDataFor(exercise.name);
                  },
                  trailingBuilder: (context, exercise, _) {
                    final bool hasPausedSets = _pausedExercises.containsKey(
                      exercise.name,
                    );
                    if (!hasPausedSets) return null;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_pausedExercises[exercise.name]!.length} in pausa',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future _confirmExitWorkout() async {
    final bool hasData =
        _activeExerciseSets.isNotEmpty ||
        _completedExercises.isNotEmpty ||
        _pausedExercises.isNotEmpty;

    if (!hasData) {
      WorkoutNotificationService().cancelRestNotifications();
      if (Platform.isIOS && _activeLiveActivityId != null) {
        await AppleLiveActivityService.stopActivity(_activeLiveActivityId!);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    HapticFeedback.mediumImpact();
    final bool? shouldExit = await showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.2,
              ),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF9700),
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Interrompere sessione?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Se esci adesso i dati e le serie registrate in questa sessione non verranno salvati.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Continua',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Esci',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );

    if (shouldExit == true && mounted) {
      WorkoutNotificationService().cancelRestNotifications();
      if (Platform.isIOS && _activeLiveActivityId != null) {
        await AppleLiveActivityService.stopActivity(_activeLiveActivityId!);
      }
      Navigator.pop(context);
    }
  }

  Future _endWorkoutSession() async {
    if (_activeExerciseSets.isNotEmpty) {
      _completedExercises.add(
        CompletedExerciseSummary(
          exerciseName: _currentExerciseName,
          muscleGroup: _currentMuscleGroup,
          sets: List.from(_activeExerciseSets),
        ),
      );
    }

    if (_pausedExercises.isNotEmpty) {
      _pausedExercises.forEach((name, sets) {
        if (sets.isNotEmpty) {
          _completedExercises.add(
            CompletedExerciseSummary(
              exerciseName: name,
              muscleGroup: 'Generale',
              sets: List.from(sets),
            ),
          );
        }
      });
    }

    if (_completedExercises.isEmpty) {
      Navigator.pop(context);
      return;
    }

    WorkoutNotificationService().cancelRestNotifications();
    if (Platform.isIOS && _activeLiveActivityId != null) {
      AppleLiveActivityService.stopActivity(_activeLiveActivityId!);
    }

    final now = DateTime.now();
    final targetDate = widget.workoutDate ?? now;
    final sessionDate = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    late Session targetSession;
    await widget.isar.writeTxn(() async {
      Session? existingSession =
          await widget.isar.sessions
              .filter()
              .dateEqualTo(sessionDate)
              .findFirst();

      if (existingSession != null) {
        existingSession.endTime = now;
        if (widget.selectedRoutine != null) {
          existingSession.routine.value = widget.selectedRoutine;
        }
        await widget.isar.sessions.put(existingSession);
        if (widget.selectedRoutine != null) {
          await existingSession.routine.save();
        }
        targetSession = existingSession;
      } else {
        final newSession =
            Session()
              ..date = sessionDate
              ..startTime = _startTime
              ..endTime = now;

        if (widget.selectedRoutine != null) {
          newSession.routine.value = widget.selectedRoutine;
        }
        await widget.isar.sessions.put(newSession);
        await newSession.routine.save();
        targetSession = newSession;
      }

      for (var exSummary in _completedExercises) {
        final exerciseEntity =
            await widget.isar.exercises
                .filter()
                .nameEqualTo(exSummary.exerciseName)
                .findFirst();

        for (var s in exSummary.sets) {
          s.session.value = targetSession;
          if (exerciseEntity != null) {
            s.exercise.value = exerciseEntity;
          }
          await widget.isar.workoutSets.put(s);
          await s.session.save();
          if (exerciseEntity != null) {
            await s.exercise.save();
          }
        }
      }
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => WorkoutSummaryScreen(
                isar: widget.isar,
                session: targetSession,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalExercises = widget.selectedRoutine?.exercises.length ?? 0;
    final double routineProgress =
        totalExercises > 0
            ? (_completedExercises.length / totalExercises).clamp(0.0, 1.0)
            : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExitWorkout();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: Column(
            children: [
              WorkoutHeader(
                routineName:
                    widget.selectedRoutine?.name ?? 'Allenamento Libero',
                elapsedSeconds: _elapsedSeconds,
                progress: routineProgress,
                hasRoutine: widget.selectedRoutine != null,
                onClose: _confirmExitWorkout,
                onFinish: _endWorkoutSession,
              ),
              WorkoutRestTimerCard(
                restRemaining: _restRemaining,
                initialRestDuration: _initialRestDuration,
                onSkip: _skipRest,
                onAddTime: _addRestTime,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ActiveExerciseCard(
                        exerciseName: _currentExerciseName,
                        muscleGroup: _currentMuscleGroup,
                        targetSets: _targetSets,
                        minReps:
                            _activeExerciseType == ExerciseType.time
                                ? 30
                                : _minReps,
                        maxReps:
                            _activeExerciseType == ExerciseType.time
                                ? 45
                                : _maxReps,
                        weight: _currentWeight,
                        reps: _currentReps,
                        exerciseType: _activeExerciseType,
                        holdSeconds: _currentHoldSeconds,
                        isWarmup: _isWarmup,
                        currentSetNumber: _activeExerciseSets.length + 1,
                        weightUnit: _activeUnit,
                        onUnitChanged: _toggleWeightUnit,
                        onSwap: _onSwapExercisePressed,
                        onWeightMinus:
                            () => setState(() {
                              _currentWeight = (_currentWeight -
                                      _globalMinWeightIncrement)
                                  .clamp(0.0, 1000.0);
                            }),
                        onWeightPlus:
                            () => setState(() {
                              _currentWeight += _globalMinWeightIncrement;
                            }),
                        onRepsMinus:
                            () => setState(
                              () =>
                                  _currentReps = (_currentReps - 1).clamp(
                                    1,
                                    100,
                                  ),
                            ),
                        onRepsPlus: () => setState(() => _currentReps += 1),
                        onHoldSecondsMinus:
                            () => setState(
                              () =>
                                  _currentHoldSeconds =
                                      (_currentHoldSeconds - 5).clamp(5, 300),
                            ),
                        onHoldSecondsPlus:
                            () => setState(() => _currentHoldSeconds += 5),
                        onWeightChanged:
                            (newWeight) => setState(
                              () =>
                                  _currentWeight = newWeight.clamp(0.0, 1000.0),
                            ),
                        onRepsChanged:
                            (newReps) => setState(
                              () => _currentReps = newReps.clamp(1, 500),
                            ),
                        onHoldSecondsChanged:
                            (newSecs) => setState(
                              () =>
                                  _currentHoldSeconds = newSecs.clamp(1, 3600),
                            ),
                        onWarmupChanged:
                            (val) => setState(() => _isWarmup = val ?? false),
                        onRegisterSet: _completeCurrentSet,
                      ),
                      const SizedBox(height: 16),
                      if (_activeExerciseSets.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SERIE EFFETTUATE',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              '${_activeExerciseSets.length} serie',
                              style: const TextStyle(
                                color: Color(0xFFFF9700),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _activeExerciseSets.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final s = _activeExerciseSets[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141414),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFFFF9700),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Set ${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (s.isWarmup) ...[
                                    const SizedBox(width: 6),
                                    const Text(
                                      '(W)',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    s.holdSeconds != null && s.holdSeconds! > 0
                                        ? '${s.weight} kg × ${s.holdSeconds} s'
                                        : '${s.weight} kg × ${s.reps} reps',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () => _removeActiveSet(i),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.redAccent,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _finishCurrentExercise,
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            color: Color(0xFFFF9700),
                            size: 18,
                          ),
                          label: const Text(
                            'CONCLUDI ESERCIZIO',
                            style: TextStyle(
                              color: Color(0xFFFF9700),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFFF9700),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_completedExercises.isNotEmpty) ...[
                        Text(
                          'ESERCIZI CONCLUSI (${_completedExercises.length})',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _completedExercises.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = _completedExercises[idx];
                            return CompletedExerciseRow(
                              exerciseName: item.exerciseName,
                              sets: item.sets,
                              onDelete: () => _removeCompletedExercise(idx),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
