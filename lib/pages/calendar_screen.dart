import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/calendar_models.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../theme/calendar_theme.dart';
import '../widgets/calendar/calendar_day_cell.dart';
import '../widgets/calendar/calendar_exercise_item.dart';
import '../widgets/calendar/calendar_header.dart';
import '../widgets/calendar/calendar_sidebar.dart';
import '../widgets/calendar/vertical_muscle_bar.dart';
import 'workout_detail_stats_screen.dart';

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

  final GlobalKey _cardStackKey = GlobalKey();
  String? _selectedMuscleGroup;
  double _selectedBarLocalTopY = 0.0;

  final ScrollController _scrollController = ScrollController();
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  Map<DateTime, List<String>> _muscleGroupDots = {};
  Map<DateTime, List<CalendarWorkoutSummary>> _workoutEvents = {};
  bool _isLoading = true;

  StreamSubscription? _sessionSubscription;
  StreamSubscription? _setSubscription;

  bool _isSelectionMode = false;
  final Set<String> _selectedExerciseKeys = {};

  double _horizontalDragAccumulator = 0.0;
  bool _hasTriggeredSwipe = false;

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
      _sessionSubscription = widget.isar!.sessions.watchLazy().listen((_) => _loadSessionsFromDb());
      _setSubscription = widget.isar!.workoutSets.watchLazy().listen((_) => _loadSessionsFromDb());
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

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  Future<void> _loadSessionsFromDb() async {
    if (widget.isar == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final sessions = await widget.isar!.sessions.where().sortByDateDesc().findAll();
      if (sessions.isEmpty) {
        if (mounted) setState(() { _muscleGroupDots = {}; _workoutEvents = {}; _isLoading = false; });
        return;
      }

      final sessionIds = sessions.map((s) => s.id).toSet();
      final Map<DateTime, Set<String>> dailyMuscleGroups = {};
      final Map<DateTime, List<CalendarWorkoutSummary>> eventsMap = {};

      final allSets = await widget.isar!.workoutSets
          .filter()
          .session((q) => q.anyOf(sessionIds, (qSession, Id id) => qSession.idEqualTo(id)))
          .findAll();

      final Map<Id, List<WorkoutSet>> sessionSetsMap = {};
      for (final set in allSets) {
        await set.session.load();
        final sId = set.session.value?.id;
        if (sId != null) sessionSetsMap.putIfAbsent(sId, () => []).add(set);
      }

      final Map<DateTime, Map<String, List<WorkoutSet>>> dailyExerciseSets = {};
      final Map<DateTime, Id> dailyPrimarySessionId = {};
      final Map<DateTime, String> dailyPrimaryTitle = {};

      for (final session in sessions) {
        final dayKey = _normalizeDate(session.date);
        await session.routine.load();
        dailyPrimarySessionId.putIfAbsent(dayKey, () => session.id);
        dailyPrimaryTitle.putIfAbsent(dayKey, () => session.routine.value?.name ?? 'Allenamento');

        final sets = sessionSetsMap[session.id] ?? [];
        if (sets.isEmpty) continue;

        dailyExerciseSets.putIfAbsent(dayKey, () => {});
        for (final set in sets) {
          await set.exercise.load();
          final ex = set.exercise.value;
          final exKey = ex?.name ?? 'Esercizio';
          dailyExerciseSets[dayKey]!.putIfAbsent(exKey, () => []).add(set);

          final rawMuscle = ex?.muscleGroup.trim() ?? '';
          if (rawMuscle.isNotEmpty) {
            final macroGroup = CalendarTheme.getNormalizedMacroGroup(rawMuscle);
            dailyMuscleGroups.putIfAbsent(dayKey, () => <String>{}).add(macroGroup);
          }
        }
      }

      for (final dayEntry in dailyExerciseSets.entries) {
        final dayKey = dayEntry.key;
        final List<ExerciseDetail> exerciseDetails = [];

        for (final entry in dayEntry.value.entries) {
          final exerciseSets = entry.value;
          final firstEx = exerciseSets.first.exercise.value;

          final totalSets = exerciseSets.length;
          final totalWeight = exerciseSets.fold<double>(0.0, (acc, s) => acc + s.weight.toDouble());
          final totalReps = exerciseSets.fold<int>(0, (acc, s) => acc + (s.reps ?? 0));
          final totalSeconds = exerciseSets.fold<int>(0, (acc, s) => acc + (s.holdSeconds ?? 0));

          exerciseDetails.add(
            ExerciseDetail(
              exerciseId: firstEx?.id,
              name: entry.key,
              muscleGroup: firstEx?.muscleGroup ?? '',
              imagePath: (firstEx as dynamic)?.imagePath as String?,
              sets: totalSets,
              avgReps: totalSets > 0 ? (totalReps / totalSets).round() : 0,
              avgSeconds: totalSets > 0 ? (totalSeconds / totalSets).round() : 0,
              avgWeight: totalSets > 0 ? (totalWeight / totalSets) : 0.0,
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

      final Map<DateTime, List<String>> dotsMap = {};
      for (final entry in dailyMuscleGroups.entries) {
        final uniqueMuscles = entry.value.toList();
        if (uniqueMuscles.isNotEmpty) {
          uniqueMuscles.sort((a, b) => CalendarTheme.getMusclePriority(a).compareTo(CalendarTheme.getMusclePriority(b)));
          dotsMap[entry.key] = uniqueMuscles.take(5).toList();
        }
      }

      if (mounted) setState(() { _muscleGroupDots = dotsMap; _workoutEvents = eventsMap; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleFormat([CalendarFormat? targetFormat]) {
    setState(() {
      _selectedMuscleGroup = null;
      _calendarFormat = targetFormat ?? (_calendarFormat == CalendarFormat.month ? CalendarFormat.week : CalendarFormat.month);
    });
    if (_calendarFormat == CalendarFormat.week) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  void _jumpToToday() {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
      _selectedMuscleGroup = null;
      _selectedExerciseKeys.clear();
      _isSelectionMode = false;
    });
    widget.onDateSelected?.call(today);
  }

  Future<void> _deleteSelectedExercises(List<ExerciseDetail> exercises) async {
    if (widget.isar == null || _selectedExerciseKeys.isEmpty) return;
    final selectedList = exercises.where((ex) => _selectedExerciseKeys.contains(ex.name)).toList();
    final count = selectedList.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Elimina Esercizi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Sei sicuro di voler rimuovere $count eserciz${count == 1 ? "io" : "i"} da questo allenamento?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final setIdsToDelete = selectedList.expand((ex) => ex.setIds).toList();

    try {
      await widget.isar!.writeTxn(() async {
        await widget.isar!.workoutSets.deleteAll(setIdsToDelete);
        final allSessions = await widget.isar!.sessions.where().findAll();
        for (final s in allSessions) {
          final countSets = await widget.isar!.workoutSets.filter().session((q) => q.idEqualTo(s.id)).count();
          if (countSets == 0) await widget.isar!.sessions.delete(s.id);
        }
      });
      setState(() { _selectedExerciseKeys.clear(); _isSelectionMode = false; _selectedMuscleGroup = null; });
      await _loadSessionsFromDb();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final List<CalendarWorkoutSummary> selectedEvents = _selectedDay != null ? (_workoutEvents[_normalizeDate(_selectedDay!)] ?? []) : [];
    final List<ExerciseDetail> currentExercises = selectedEvents.expand<ExerciseDetail>((s) => s.exercises).toList();

    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double cutOffBottom = bottomInset > 20 ? bottomInset - 20 : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF9700)))
            : Column(
          children: [
            // --- 1. SEZIONE CALENDARIO SUPERIORE ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CalendarHeader(
                    focusedDay: _focusedDay,
                    onPrevious: () => setState(() {
                      _selectedMuscleGroup = null;
                      _focusedDay = _calendarFormat == CalendarFormat.week
                          ? _focusedDay.subtract(const Duration(days: 7))
                          : DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day.clamp(1, 28));
                    }),
                    onNext: () => setState(() {
                      _selectedMuscleGroup = null;
                      _focusedDay = _calendarFormat == CalendarFormat.week
                          ? _focusedDay.add(const Duration(days: 7))
                          : DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day.clamp(1, 28));
                    }),
                  ),

                  // Griglia TableCalendar
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) { _horizontalDragAccumulator = 0.0; _hasTriggeredSwipe = false; },
                    onHorizontalDragUpdate: (details) {
                      if (_hasTriggeredSwipe) return;
                      _horizontalDragAccumulator += details.primaryDelta ?? 0.0;
                      if (_horizontalDragAccumulator < -28.0) {
                        _hasTriggeredSwipe = true;
                        setState(() => _focusedDay = _calendarFormat == CalendarFormat.week ? _focusedDay.add(const Duration(days: 7)) : DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day.clamp(1, 28)));
                      } else if (_horizontalDragAccumulator > 28.0) {
                        _hasTriggeredSwipe = true;
                        setState(() => _focusedDay = _calendarFormat == CalendarFormat.week ? _focusedDay.subtract(const Duration(days: 7)) : DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day.clamp(1, 28)));
                      }
                    },
                    onHorizontalDragEnd: (_) { _horizontalDragAccumulator = 0.0; _hasTriggeredSwipe = false; },
                    child: TableCalendar<CalendarWorkoutSummary>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      availableGestures: AvailableGestures.none,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerVisible: false,
                      daysOfWeekVisible: false,
                      rowHeight: 60.0,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _selectedExerciseKeys.clear();
                          _isSelectionMode = false;
                          _selectedMuscleGroup = null;
                        });
                        widget.onDateSelected?.call(selectedDay);
                      },
                      onPageChanged: (focusedDay) => setState(() { _focusedDay = focusedDay; _selectedMuscleGroup = null; }),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, _) => CalendarDayCell(
                          day: day,
                          textColor: Colors.white,
                          borderColor: const Color(0xFF242424),
                          backgroundColor: Colors.transparent,
                          muscleGroups: _muscleGroupDots[_normalizeDate(day)] ?? const [],
                        ),
                        selectedBuilder: (context, day, _) {
                          final isToday = isSameDay(day, DateTime.now());
                          return CalendarDayCell(
                            day: day,
                            textColor: isToday ? const Color(0xFFFF9700) : Colors.white,
                            borderColor: const Color(0xFFFF9700),
                            borderWidth: 1.8,
                            backgroundColor: isToday ? const Color(0xFF2C2C2E) : Colors.transparent,
                            muscleGroups: _muscleGroupDots[_normalizeDate(day)] ?? const [],
                          );
                        },
                        todayBuilder: (context, day, _) => CalendarDayCell(
                          day: day,
                          textColor: Colors.white,
                          borderColor: const Color(0xFFFF9700).withValues(alpha: 0.5),
                          borderWidth: 1.4,
                          backgroundColor: const Color(0xFF2C2C2E),
                          muscleGroups: _muscleGroupDots[_normalizeDate(day)] ?? const [],
                        ),
                        outsideBuilder: (context, day, _) => Center(
                          child: Text('${day.day}', style: const TextStyle(color: Color(0xFF424242), fontSize: 15, fontWeight: FontWeight.w400)),
                        ),
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
                padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: cutOffBottom),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF232325),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Column(
                      children: [
                        // Maniglia Drag
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) {
                            if (details.primaryDelta != null) {
                              if (details.primaryDelta! < -4 && _calendarFormat == CalendarFormat.month) _toggleFormat(CalendarFormat.week);
                              if (details.primaryDelta! > 4 && _calendarFormat == CalendarFormat.week) _toggleFormat(CalendarFormat.month);
                            }
                          },
                          onTap: () => _toggleFormat(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 4.5,
                                decoration: BoxDecoration(color: const Color(0xFFFF9700), borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),

                        // Corpo Card
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notif) {
                              if (notif is ScrollUpdateNotification && _selectedMuscleGroup != null) {
                                setState(() => _selectedMuscleGroup = null);
                              }
                              return false;
                            },
                            child: Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (e) {
                                if (_selectedMuscleGroup != null && (e.localPosition.dx > 260 || e.localPosition.dx < 76)) {
                                  setState(() => _selectedMuscleGroup = null);
                                }
                              },
                              child: Stack(
                                key: _cardStackKey,
                                clipBehavior: Clip.none,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CalendarSidebar(
                                        selectedDay: _selectedDay ?? DateTime.now(),
                                        isSelectionMode: _isSelectionMode,
                                        selectedCount: _selectedExerciseKeys.length,
                                        currentExercises: currentExercises,
                                        selectedMuscleGroup: _selectedMuscleGroup,
                                        cardStackKey: _cardStackKey,
                                        onJumpToToday: _jumpToToday,
                                        onToggleSelectionMode: () => setState(() {
                                          _selectedMuscleGroup = null;
                                          _isSelectionMode = !_isSelectionMode;
                                          if (!_isSelectionMode) _selectedExerciseKeys.clear();
                                        }),
                                        onDeleteSelected: () => _deleteSelectedExercises(currentExercises),
                                        onBarSegmentSelected: (group, topY) {
                                          setState(() {
                                            if (_selectedMuscleGroup == group) {
                                              _selectedMuscleGroup = null;
                                            } else {
                                              _selectedMuscleGroup = group;
                                              _selectedBarLocalTopY = topY;
                                            }
                                          });
                                        },
                                      ),
                                      Container(width: 1.5, margin: const EdgeInsets.only(top: 4.0, bottom: 20.0), color: Colors.white24),
                                      Expanded(
                                        child: currentExercises.isEmpty
                                            ? const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.event_busy_rounded, color: Colors.white24, size: 40),
                                              SizedBox(height: 8),
                                              Text('Nessun allenamento', style: TextStyle(color: Colors.white60, fontSize: 14)),
                                            ],
                                          ),
                                        )
                                            : ListView.builder(
                                          controller: _scrollController,
                                          physics: const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
                                          itemCount: currentExercises.length,
                                          itemBuilder: (context, index) {
                                            final exercise = currentExercises[index];
                                            return CalendarExerciseItem(
                                              exercise: exercise,
                                              isSelected: _selectedExerciseKeys.contains(exercise.name),
                                              isSelectionMode: _isSelectionMode,
                                              expandAnimation: _expandAnimation,
                                              onTap: () {
                                                if (_isSelectionMode) {
                                                  setState(() {
                                                    if (_selectedExerciseKeys.contains(exercise.name)) {
                                                      _selectedExerciseKeys.remove(exercise.name);
                                                    } else {
                                                      _selectedExerciseKeys.add(exercise.name);
                                                    }
                                                  });
                                                } else {
                                                  HapticFeedback.selectionClick();
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => ExerciseDetailStatsScreen(
                                                        isar: widget.isar,
                                                        exerciseName: exercise.name,
                                                        muscleGroup: exercise.muscleGroup,
                                                        imagePath: exercise.imagePath,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Mini Pop-up se attivo
                                  if (_selectedMuscleGroup != null)
                                    MuscleBarPopup(
                                      selectedGroup: _selectedMuscleGroup!,
                                      topPosition: _selectedBarLocalTopY,
                                      exercises: currentExercises,
                                      onClose: () => setState(() => _selectedMuscleGroup = null),
                                    ),
                                ],
                              ),
                            ),
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
}