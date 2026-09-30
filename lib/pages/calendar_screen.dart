import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/exercise.dart';
import '../models/session.dart';
import '../models/workout_set.dart';

class ExerciseDetail {
  final Id? exerciseId;
  final String name;
  final String muscleGroup;
  final String? imagePath;
  final int sets;
  final int avgReps;
  final int avgSeconds;
  final double avgWeight;
  final List<Id> setIds;

  const ExerciseDetail({
    this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.imagePath,
    required this.sets,
    required this.avgReps,
    required this.avgSeconds,
    required this.avgWeight,
    required this.setIds,
  });
}

class CalendarWorkoutSummary {
  final Id sessionId;
  final String title;
  final List<ExerciseDetail> exercises;

  const CalendarWorkoutSummary({
    required this.sessionId,
    required this.title,
    required this.exercises,
  });
}

class CalendarScreen extends StatefulWidget {
  final Isar? isar;
  final ValueChanged<DateTime>? onDateSelected;
  const CalendarScreen({super.key, this.isar, this.onDateSelected});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final ScrollController _scrollController = ScrollController();
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  // Dati estratti da Isar
  Map<DateTime, int> _muscleGroupDots = {};
  Map<DateTime, List<CalendarWorkoutSummary>> _workoutEvents = {};
  bool _isLoading = true;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _setSubscription;

  // Stato selezione & eliminazione esercizi
  bool _isSelectionMode = false;
  final Set<String> _selectedExerciseKeys = {};

  // Variabili swipe calendario
  double _horizontalDragAccumulator = 0.0;
  bool _hasTriggeredSwipe = false;

  final List<String> _monthNames = [
    'Gennaio',
    'Febbraio',
    'Marzo',
    'Aprile',
    'Maggio',
    'Giugno',
    'Luglio',
    'Agosto',
    'Settembre',
    'Ottobre',
    'Novembre',
    'Dicembre',
  ];

  final List<String> _weekdayNames = [
    'lun',
    'mar',
    'mer',
    'gio',
    'ven',
    'sab',
    'dom',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubicEmphasized,
    );

    _loadSessionsFromDb();

    if (widget.isar != null) {
      _sessionSubscription = widget.isar!.sessions.watchLazy().listen((_) {
        _loadSessionsFromDb();
      });
      _setSubscription = widget.isar!.workoutSets.watchLazy().listen((_) {
        _loadSessionsFromDb();
      });
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _setSubscription?.cancel();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _loadSessionsFromDb() async {
    if (widget.isar == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final sessions =
          await widget.isar!.sessions.where().sortByDateDesc().findAll();

      if (sessions.isEmpty) {
        if (mounted) {
          setState(() {
            _muscleGroupDots = {};
            _workoutEvents = {};
            _isLoading = false;
          });
        }
        return;
      }

      final sessionIds = sessions.map((s) => s.id).toSet();
      final Map<DateTime, Set<String>> dailyMuscleGroups = {};
      final Map<DateTime, List<CalendarWorkoutSummary>> eventsMap = {};

      final allSets =
          await widget.isar!.workoutSets
              .filter()
              .session(
                (q) => q.anyOf(
                  sessionIds,
                  (qSession, Id id) => qSession.idEqualTo(id),
                ),
              )
              .findAll();

      // Mappa: sessionId -> lista dei suoi set
      final Map<Id, List<WorkoutSet>> sessionSetsMap = {};
      for (final set in allSets) {
        await set.session.load();
        final sId = set.session.value?.id;
        if (sId != null) {
          sessionSetsMap.putIfAbsent(sId, () => []).add(set);
        }
      }

      // Mappa per aggregare tutti i set della giornata raggruppati per giorno:
      // DateTime (dayKey) -> Map<NomeEsercizio, List<WorkoutSet>>
      final Map<DateTime, Map<String, List<WorkoutSet>>> dailyExerciseSets = {};
      final Map<DateTime, Id> dailyPrimarySessionId = {};
      final Map<DateTime, String> dailyPrimaryTitle = {};

      for (final session in sessions) {
        final dayKey = _normalizeDate(session.date);
        await session.routine.load();
        final routineTitle = session.routine.value?.name ?? 'Allenamento';

        dailyPrimarySessionId.putIfAbsent(dayKey, () => session.id);
        dailyPrimaryTitle.putIfAbsent(dayKey, () => routineTitle);

        final sets = sessionSetsMap[session.id] ?? [];
        if (sets.isEmpty) continue;

        dailyExerciseSets.putIfAbsent(dayKey, () => {});

        for (final set in sets) {
          await set.exercise.load();
          final ex = set.exercise.value;
          final exKey = ex?.name ?? 'Esercizio';

          dailyExerciseSets[dayKey]!.putIfAbsent(exKey, () => []).add(set);

          final muscle = ex?.muscleGroup.trim() ?? '';
          if (muscle.isNotEmpty) {
            dailyMuscleGroups.putIfAbsent(dayKey, () => {}).add(muscle);
          }
        }
      }

      // Costruzione dei riepiloghi giornalieri unificati
      for (final dayEntry in dailyExerciseSets.entries) {
        final dayKey = dayEntry.key;
        final exerciseGroups = dayEntry.value;

        final List<ExerciseDetail> exerciseDetails = [];

        for (final entry in exerciseGroups.entries) {
          final exerciseName = entry.key;
          final exerciseSets = entry.value;

          final firstEx = exerciseSets.first.exercise.value;
          final muscle = firstEx?.muscleGroup ?? '';
          final exId = firstEx?.id;
          final String? dbImagePath =
              (firstEx as dynamic)?.imagePath as String?;

          final totalSetsCount = exerciseSets.length;
          final double totalWeight = exerciseSets.fold<double>(
            0.0,
            (acc, s) => acc + s.weight.toDouble(),
          );

          final int totalReps = exerciseSets.fold<int>(
            0,
            (acc, s) => acc + (s.reps ?? 0),
          );
          final int totalSeconds = exerciseSets.fold<int>(
            0,
            (acc, s) => acc + (s.holdSeconds ?? 0),
          );

          final int avgReps =
              totalSetsCount > 0 ? (totalReps / totalSetsCount).round() : 0;
          final int avgSeconds =
              totalSetsCount > 0 ? (totalSeconds / totalSetsCount).round() : 0;
          final double avgWeight =
              totalSetsCount > 0 ? (totalWeight / totalSetsCount) : 0.0;

          exerciseDetails.add(
            ExerciseDetail(
              exerciseId: exId,
              name: exerciseName,
              muscleGroup: muscle,
              imagePath: dbImagePath,
              sets: totalSetsCount,
              avgReps: avgReps,
              avgSeconds: avgSeconds,
              avgWeight: avgWeight,
              setIds: exerciseSets.map((s) => s.id).toList(),
            ),
          );
        }

        if (exerciseDetails.isNotEmpty) {
          eventsMap[dayKey] = [
            CalendarWorkoutSummary(
              sessionId: dailyPrimarySessionId[dayKey] ?? 0,
              title: dailyPrimaryTitle[dayKey] ?? 'Allenamento',
              exercises: exerciseDetails,
            ),
          ];
        }
      }

      // Conteggio pallini muscolari
      final Map<DateTime, int> dotsMap = {};
      for (final entry in dailyMuscleGroups.entries) {
        final day = entry.key;
        final muscles = entry.value;
        if (muscles.isNotEmpty) {
          dotsMap[day] = muscles.length.clamp(1, 4);
        }
      }

      if (mounted) {
        setState(() {
          _muscleGroupDots = dotsMap;
          _workoutEvents = eventsMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CalendarWorkoutSummary> _getEventsForDay(DateTime day) {
    return _workoutEvents[_normalizeDate(day)] ?? [];
  }

  int _getDotsCount(DateTime day) {
    return _muscleGroupDots[_normalizeDate(day)] ?? 0;
  }

  void _toggleFormat([CalendarFormat? targetFormat]) {
    setState(() {
      if (targetFormat != null) {
        _calendarFormat = targetFormat;
      } else {
        _calendarFormat =
            _calendarFormat == CalendarFormat.month
                ? CalendarFormat.week
                : CalendarFormat.month;
      }
    });

    if (_calendarFormat == CalendarFormat.week) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _goToPrevious() {
    setState(() {
      if (_calendarFormat == CalendarFormat.week) {
        _focusedDay = _focusedDay.subtract(const Duration(days: 7));
      } else {
        _focusedDay = DateTime(
          _focusedDay.year,
          _focusedDay.month - 1,
          _focusedDay.day.clamp(1, 28),
        );
      }
    });
  }

  void _goToNext() {
    setState(() {
      if (_calendarFormat == CalendarFormat.week) {
        _focusedDay = _focusedDay.add(const Duration(days: 7));
      } else {
        _focusedDay = DateTime(
          _focusedDay.year,
          _focusedDay.month + 1,
          _focusedDay.day.clamp(1, 28),
        );
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedExerciseKeys.clear();
      }
    });
  }

  void _toggleExerciseSelection(String key) {
    setState(() {
      if (_selectedExerciseKeys.contains(key)) {
        _selectedExerciseKeys.remove(key);
      } else {
        _selectedExerciseKeys.add(key);
      }
    });
  }

  Future<void> _deleteSelectedExercises(List<ExerciseDetail> exercises) async {
    if (widget.isar == null || _selectedExerciseKeys.isEmpty) return;

    final selectedList =
        exercises
            .where((ex) => _selectedExerciseKeys.contains(ex.name))
            .toList();

    final count = selectedList.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Elimina Esercizi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Sei sicuro di voler rimuovere $count eserciz${count == 1 ? "io" : "i"} da questo allenamento?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Annulla',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Elimina',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final setIdsToDelete = <Id>[];
    for (final ex in selectedList) {
      setIdsToDelete.addAll(ex.setIds);
    }

    try {
      await widget.isar!.writeTxn(() async {
        await widget.isar!.workoutSets.deleteAll(setIdsToDelete);

        final allSessions = await widget.isar!.sessions.where().findAll();
        for (final s in allSessions) {
          final countSets =
              await widget.isar!.workoutSets
                  .filter()
                  .session((q) => q.idEqualTo(s.id))
                  .count();
          if (countSets == 0) {
            await widget.isar!.sessions.delete(s.id);
          }
        }
      });

      setState(() {
        _selectedExerciseKeys.clear();
        _isSelectionMode = false;
      });

      await _loadSessionsFromDb();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<CalendarWorkoutSummary> selectedEvents =
        _selectedDay != null
            ? _getEventsForDay(_selectedDay!)
            : <CalendarWorkoutSummary>[];

    final List<ExerciseDetail> currentExercises =
        selectedEvents
            .expand<ExerciseDetail>((summary) => summary.exercises)
            .toList();

    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double cutOffBottom = bottomInset > 20 ? bottomInset - 20 : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF9700)),
                )
                : Column(
                  children: [
                    // --- 1. CALENDARIO IN ALTO ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 10.0,
                              bottom: 12.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: Color(0xFFFF9700),
                                    size: 38,
                                  ),
                                  onPressed: _goToPrevious,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_focusedDay.year}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _monthNames[_focusedDay.month - 1],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFFF9700),
                                    size: 38,
                                  ),
                                  onPressed: _goToNext,
                                ),
                              ],
                            ),
                          ),

                          // Header giorni della settimana pillola
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            margin: const EdgeInsets.only(bottom: 12.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF191919),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text(
                                  'Lun',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Mar',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Mer',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Gio',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Ven',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Sab',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Dom',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Griglia Giorni
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) {
                              _horizontalDragAccumulator = 0.0;
                              _hasTriggeredSwipe = false;
                            },
                            onHorizontalDragUpdate: (details) {
                              if (_hasTriggeredSwipe) return;

                              _horizontalDragAccumulator +=
                                  details.primaryDelta ?? 0.0;
                              const double swipeThreshold = 28.0;

                              if (_horizontalDragAccumulator <
                                  -swipeThreshold) {
                                _hasTriggeredSwipe = true;
                                _goToNext();
                              } else if (_horizontalDragAccumulator >
                                  swipeThreshold) {
                                _hasTriggeredSwipe = true;
                                _goToPrevious();
                              }
                            },
                            onHorizontalDragEnd: (_) {
                              _horizontalDragAccumulator = 0.0;
                              _hasTriggeredSwipe = false;
                            },
                            child: TableCalendar<CalendarWorkoutSummary>(
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              calendarFormat: _calendarFormat,
                              availableGestures: AvailableGestures.none,
                              formatAnimationDuration: const Duration(
                                milliseconds: 350,
                              ),
                              formatAnimationCurve: Curves.easeOutQuad,
                              pageAnimationDuration: const Duration(
                                milliseconds: 260,
                              ),
                              pageAnimationCurve: Curves.easeOutCubic,
                              pageJumpingEnabled: false,
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              headerVisible: false,
                              daysOfWeekVisible: false,
                              rowHeight: 60.0,
                              daysOfWeekHeight: 0,
                              selectedDayPredicate:
                                  (day) => isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                  _selectedExerciseKeys.clear();
                                  _isSelectionMode = false;
                                });
                                widget.onDateSelected?.call(selectedDay);
                              },
                              onPageChanged: (focusedDay) {
                                setState(() {
                                  _focusedDay = focusedDay;
                                });
                              },
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  return _buildSquareCell(
                                    day: day,
                                    textColor: Colors.white,
                                    borderColor: const Color(0xFF242424),
                                    backgroundColor: Colors.transparent,
                                    dotsCount: _getDotsCount(day),
                                  );
                                },
                                selectedBuilder: (context, day, focusedDay) {
                                  final bool isCurrentDay = isSameDay(
                                    day,
                                    DateTime.now(),
                                  );
                                  return _buildSquareCell(
                                    day: day,
                                    textColor: Colors.white,
                                    borderColor: const Color(0xFFFF9700),
                                    borderWidth: 1.8,
                                    backgroundColor:
                                        isCurrentDay
                                            ? const Color(0xFF2C2C2E)
                                            : Colors.transparent,
                                    dotsCount: _getDotsCount(day),
                                  );
                                },
                                todayBuilder: (context, day, focusedDay) {
                                  return _buildSquareCell(
                                    day: day,
                                    textColor: Colors.white,
                                    borderColor: const Color(
                                      0xFFFF9700,
                                    ).withValues(alpha: 0.5),
                                    borderWidth: 1.4,
                                    backgroundColor: const Color(0xFF2C2C2E),
                                    dotsCount: _getDotsCount(day),
                                  );
                                },
                                outsideBuilder: (context, day, focusedDay) {
                                  return Center(
                                    child: Text(
                                      '${day.day}',
                                      style: const TextStyle(
                                        color: Color(0xFF424242),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // --- 2. CARD INFERIORE ADATTIVA ---
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16.0,
                          right: 16.0,
                          bottom: cutOffBottom,
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF232325),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                              bottom: Radius.circular(0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                              bottom: Radius.circular(0),
                            ),
                            child: Column(
                              children: [
                                // Maniglietta Drag
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onVerticalDragUpdate: (details) {
                                    if (details.primaryDelta != null) {
                                      if (details.primaryDelta! < -4 &&
                                          _calendarFormat ==
                                              CalendarFormat.month) {
                                        _toggleFormat(CalendarFormat.week);
                                      } else if (details.primaryDelta! > 4 &&
                                          _calendarFormat ==
                                              CalendarFormat.week) {
                                        _toggleFormat(CalendarFormat.month);
                                      }
                                    }
                                  },
                                  onTap: () => _toggleFormat(),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.only(
                                      top: 12.0,
                                      bottom: 8.0,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 44,
                                        height: 4.5,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF9700),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Corpo Card: Colonna fissa Sinistra + Lista Esercizi
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildLeftSidebar(currentExercises),
                                      Container(
                                        width: 1.5,
                                        margin: const EdgeInsets.only(
                                          top: 4.0,
                                          bottom: 20.0,
                                        ),
                                        color: Colors.white24,
                                      ),
                                      Expanded(
                                        child:
                                            currentExercises.isEmpty
                                                ? _buildEmptyState()
                                                : ListView.builder(
                                                  controller: _scrollController,
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        16.0,
                                                        4.0,
                                                        16.0,
                                                        80.0,
                                                      ),
                                                  itemCount:
                                                      currentExercises.length,
                                                  itemBuilder: (
                                                    context,
                                                    index,
                                                  ) {
                                                    return _buildAnimatedExerciseItem(
                                                      currentExercises[index],
                                                    );
                                                  },
                                                ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildLeftSidebar(List<ExerciseDetail> currentExercises) {
    final currentDay = _selectedDay ?? DateTime.now();
    final dayNum = '${currentDay.day}';
    final weekday = _weekdayNames[currentDay.weekday - 1];

    final hasSelectedItems = _selectedExerciseKeys.isNotEmpty;

    return Container(
      width: 76,
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            dayNum,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          Text(
            weekday,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),

          // Tasto 1: Attiva / Disattiva selezione
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip:
                _isSelectionMode ? 'Annulla selezione' : 'Seleziona esercizi',
            icon: Icon(
              Icons.pan_tool_alt_rounded,
              color: _isSelectionMode ? Colors.white : const Color(0xFFFF9700),
              size: 26,
            ),
            onPressed: currentExercises.isEmpty ? null : _toggleSelectionMode,
          ),

          const SizedBox(height: 18),

          // Tasto 2: Elimina esercizi selezionati (visibile solo in selection mode)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
              );
            },
            child:
                _isSelectionMode
                    ? Padding(
                      key: const ValueKey('delete_button_visible'),
                      padding: const EdgeInsets.symmetric(vertical: 0.0),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip:
                            hasSelectedItems
                                ? 'Elimina (${_selectedExerciseKeys.length})'
                                : 'Seleziona almeno un esercizio',
                        icon: Icon(
                          Icons.delete_rounded,
                          color:
                              hasSelectedItems
                                  ? Colors.redAccent
                                  : Colors.white24,
                          size: 26,
                        ),
                        onPressed:
                            hasSelectedItems
                                ? () =>
                                    _deleteSelectedExercises(currentExercises)
                                : null,
                      ),
                    )
                    : const SizedBox.shrink(
                      key: ValueKey('delete_button_hidden'),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseThumbnail(String? imagePath, double size) {
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      final trimmed = imagePath.trim();

      // Controllo se è un file salvato localmente
      if (File(trimmed).existsSync()) {
        return Image.file(
          File(trimmed),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackDumbbellIcon(),
        );
      }

      // Controllo se è una URL web
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return Image.network(
          trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackDumbbellIcon(),
        );
      }

      // Controllo se è un asset locale
      if (trimmed.startsWith('assets/')) {
        return Image.asset(
          trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackDumbbellIcon(),
        );
      }
    }

    // Se non presente, renderizza l'icona del manubrio
    return _buildFallbackDumbbellIcon();
  }

  Widget _buildFallbackDumbbellIcon() {
    return Container(
      color: const Color(0xFF1E1E1E),
      alignment: Alignment.center,
      child: const Icon(
        Icons.fitness_center_rounded,
        color: Color(0xFFFF9700),
        size: 22,
      ),
    );
  }

  Widget _buildAnimatedExerciseItem(ExerciseDetail exercise) {
    final isSelected = _selectedExerciseKeys.contains(exercise.name);

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final t = _expandAnimation.value;

        final double imageSize = 44.0 + (32.0 * t);
        final double imageRadius = 14.0 + (6.0 * t);
        final double itemMarginBottom = 16.0 + (4.0 * t);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_isSelectionMode) {
              _toggleExerciseSelection(exercise.name);
            }
          },
          child: Container(
            margin: EdgeInsets.only(bottom: itemMarginBottom),
            padding: EdgeInsets.symmetric(
              vertical: 4.0,
              horizontal: _isSelectionMode ? 8.0 : 0.0,
            ),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFFFF9700).withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border:
                  isSelected
                      ? Border.all(color: const Color(0xFFFF9700), width: 1.2)
                      : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Indicatore Checkbox quando in modalità selezione
                if (_isSelectionMode) ...[
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isSelected
                              ? const Color(0xFFFF9700)
                              : Colors.transparent,
                      border: Border.all(
                        color:
                            isSelected
                                ? const Color(0xFFFF9700)
                                : Colors.white38,
                        width: 1.6,
                      ),
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.black,
                            )
                            : null,
                  ),
                ],

                // Thumbnail immagine o icona manubrio di fallback
                ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    color: const Color(0xFF2C2C2E),
                    child: _buildExerciseThumbnail(
                      exercise.imagePath,
                      imageSize,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? const Color(0xFFFF9700)
                                  : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (t < 0.15)
                        Container(
                          height: 2.0,
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4.0, right: 75.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9700),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 2.0,
                                margin: const EdgeInsets.only(
                                  right: 8.0,
                                  top: 2.0,
                                  bottom: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF9700,
                                  ).withValues(alpha: t.clamp(0.0, 1.0)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Series tot: ${exercise.sets}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      exercise.avgSeconds > 0
                                          ? 'Average time: ${exercise.avgSeconds}s'
                                          : 'Average reps: ${exercise.avgReps}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      'Average weight: ${exercise.avgWeight.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: Colors.white.withValues(alpha: 0.2),
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nessun allenamento',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareCell({
    required DateTime day,
    required Color textColor,
    required Color borderColor,
    required Color backgroundColor,
    double borderWidth = 1.0,
    required int dotsCount,
  }) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        margin: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (dotsCount > 0) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  dotsCount > 4 ? 4 : dotsCount,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    width: 4.5,
                    height: 4.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9700),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
