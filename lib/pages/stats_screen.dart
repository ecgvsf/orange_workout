import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/stats_model.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../models/exercise.dart';

import '../widgets/stats/volume_trend_card.dart';
import '../widgets/stats/one_rm_progression_chart_card.dart';
import '../widgets/stats/exercise_session_data_card.dart';
import '../widgets/stats/muscle_split_progress_card.dart';
import '../widgets/stats/stats_chart_utils.dart';

class StatsScreen extends StatefulWidget {
  final Isar? isar;

  const StatsScreen({super.key, this.isar});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  double _topScrollOffset = 0.0;

  late final AnimationController _generalAnimController;
  late final Animation<double> _generalCurveAnimation;

  late final AnimationController _oneRmAnimController;
  late final Animation<double> _oneRmCurveAnimation;

  TimeFilter _selectedFilter = TimeFilter.week;
  String _globalWeightUnit = 'kg';

  bool _isLoading = true;
  List<CompoundExerciseInfo> _compoundList = [];
  String? _selectedExercise;

  // Dati KPI Aggregati
  double _totalTonnage = 0.0;
  int _completedSessionsCount = 0;
  double _avgRpe = 0.0;
  double _density = 0.0;

  // Dati per VolumeTrendCard (accetta List<double> o List<MonthlyWeekBarData>)
  List<dynamic> _volumeChartData = [];
  List<String> _volumeChartLabels = [];

  // Dati per MuscleSplitProgressCard
  List<Map<String, dynamic>> _muscleData = [];

  // --- COSTANTI DI CONFIGURAZIONE GRUPPI MUSCOLARI ---
  static const List<String> _muscleOrder = [
    'Petto',
    'Dorso',
    'Spalle',
    'Tricipiti',
    'Bicipiti',
    'Gambe',
    'Core',
  ];

  static const Map<String, int> _baseWeeklyTargets = {
    'Petto': 16,
    'Dorso': 16,
    'Gambe': 18,
    'Spalle': 12,
    'Tricipiti': 10,
    'Bicipiti': 10,
    'Core': 8,
  };

  static const Map<String, Color> _groupColors = {
    'Petto': Color(0xFFD32F2F),
    'Dorso': Color(0xFFE64A19),
    'Spalle': Color(0xFFFF9700),
    'Tricipiti': Color(0xFFFFC107),
    'Bicipiti': Color(0xFFFFEE58),
    'Gambe': Color(0xFFFFF9C4),
    'Core': Colors.white,
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _generalAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _generalCurveAnimation = CurvedAnimation(
      parent: _generalAnimController,
      curve: Curves.easeOutCubic,
    );

    _oneRmAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _oneRmCurveAnimation = CurvedAnimation(
      parent: _oneRmAnimController,
      curve: Curves.easeOutCubic,
    );

    _generalAnimController.forward();
    _oneRmAnimController.forward();

    _loadExercisesAndStats();
    // Ascolta il refresh globale scattato dal main
    globalRefreshNotifier.addListener(_onGlobalRefreshTriggered);
  }

  void _onGlobalRefreshTriggered() {
    if (mounted) {
      _loadExercisesAndStats();
      _generalAnimController.forward(from: 0.0);
      _oneRmAnimController.forward(from: 0.0);
    }
  }

  void _onScroll() {
    final double offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final double clamped = offset.clamp(0.0, 35.0);
    if (clamped != _topScrollOffset) {
      setState(() => _topScrollOffset = clamped);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _generalAnimController.dispose();
    _oneRmAnimController.dispose();
    globalRefreshNotifier.removeListener(_onGlobalRefreshTriggered);
    super.dispose();
  }

  void _changeTimeFilter(TimeFilter filter) {
    if (_selectedFilter == filter) return;
    HapticFeedback.selectionClick();
    _selectedFilter = filter;
    _fetchDatabaseStats();
  }

  // =========================================================================
  // METODI HELPER MODULARI
  // =========================================================================

  DateTime _calculateCalendarStartDate(DateTime now, TimeFilter filter) {
    switch (filter) {
      case TimeFilter.week:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
      case TimeFilter.month:
        return DateTime(now.year, now.month, 1);
      case TimeFilter.year:
        return DateTime(now.year, 1, 1);
    }
  }

  String _getMainMuscleGroup(String rawMuscle) {
    final lower = rawMuscle.toLowerCase().trim();
    if (lower.contains('petto') || lower.contains('chest')) return 'Petto';
    if (lower.contains('dorso') ||
        lower.contains('back') ||
        lower.contains('lats') ||
        lower.contains('trapez')) {
      return 'Dorso';
    }
    if (lower.contains('spall') || lower.contains('deltoid')) return 'Spalle';
    if (lower.contains('tricipit')) return 'Tricipiti';
    if (lower.contains('bicipit') ||
        lower.contains('braccia') ||
        lower.contains('avambracc')) {
      return 'Bicipiti';
    }
    if (lower.contains('quad') ||
        lower.contains('femorali') ||
        lower.contains('glute') ||
        lower.contains('polpacc') ||
        lower.contains('gambe')) {
      return 'Gambe';
    }
    if (lower.contains('addom') ||
        lower.contains('core') ||
        lower.contains('abs') ||
        lower.contains('lombari')) {
      return 'Core';
    }
    return 'Altro';
  }

  int _calculateVolumeBucketKey(DateTime sDate, TimeFilter filter) {
    if (filter == TimeFilter.week) {
      return sDate.weekday - 1; // 0..6 (Lun..Dom)
    } else {
      return sDate.month - 1; // 0..11 (Gen..Dic)
    }
  }

  Map<String, dynamic> _computeStandardVolumeChartData({
    required Map<int, double> volumeBucket,
    required TimeFilter filter,
  }) {
    List<double> data = [];
    List<String> labels = [];

    if (filter == TimeFilter.week) {
      labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
      data = List.generate(7, (i) => volumeBucket[i] ?? 0.0);
    } else {
      labels = ['G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];
      data = List.generate(12, (i) => volumeBucket[i] ?? 0.0);
    }

    return {'data': data, 'labels': labels};
  }

  /// Calcola i dati per le settimane a cavallo del mese (Barre Sdoppiate)
  List<MonthlyWeekBarData> _computeMonthlySplitBars({
    required DateTime now,
    required List<WorkoutSet> sets,
    required Map<Id, DateTime> sessionDateMap,
    required String weightUnit,
  }) {
    final int year = now.year;
    final int month = now.month;
    final int totalDaysInMonth = DateTime(year, month + 1, 0).day;

    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month, totalDaysInMonth);

    // Primo lunedì (anche se nel mese precedente)
    final calendarStart = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday - 1),
    );

    // Ultima domenica (anche se nel mese successivo)
    final calendarEnd = lastDayOfMonth.add(
      Duration(days: 7 - lastDayOfMonth.weekday),
    );

    final Map<DateTime, double> dayVolumeMap = {};
    for (final s in sets) {
      if (s.isWarmup) continue;
      final sId = s.session.value?.id;
      final sDate = sId != null ? sessionDateMap[sId] : null;
      if (sDate == null) continue;

      final dayKey = DateTime(sDate.year, sDate.month, sDate.day);
      if (dayKey.isBefore(calendarStart) || dayKey.isAfter(calendarEnd))
        continue;

      double w = s.weight;
      if (weightUnit == 'lbs') w *= 2.20462;
      final double setVol = w * (s.reps ?? 1);

      dayVolumeMap[dayKey] = (dayVolumeMap[dayKey] ?? 0.0) + setVol;
    }

    final List<MonthlyWeekBarData> resultBars = [];
    DateTime curMonday = calendarStart;

    while (curMonday.isBefore(calendarEnd)) {
      double insideVolume = 0.0;
      double outsideVolume = 0.0;

      for (int i = 0; i < 7; i++) {
        final curDay = curMonday.add(Duration(days: i));
        final vol = dayVolumeMap[curDay] ?? 0.0;

        if (curDay.month == month) {
          insideVolume += vol;
        } else {
          outsideVolume += vol;
        }
      }

      final curSunday = curMonday.add(const Duration(days: 6));
      final int startLabelDay = curMonday.month == month ? curMonday.day : 1;
      final int endLabelDay =
          curSunday.month == month ? curSunday.day : totalDaysInMonth;

      resultBars.add(
        MonthlyWeekBarData(
          currentMonthVolume: insideVolume,
          outsideMonthVolume: outsideVolume,
          label: '$startLabelDay-$endLabelDay',
        ),
      );

      curMonday = curMonday.add(const Duration(days: 7));
    }

    return resultBars;
  }

  List<Map<String, dynamic>> _buildMuscleSplitData({
    required Map<String, int> mainSets,
    required Map<String, List<Map<String, dynamic>>> mainExercises,
    required int multiplier,
  }) {
    return _muscleOrder.map((group) {
      final baseTarget = _baseWeeklyTargets[group] ?? 12;
      return {
        'muscle': group,
        'sets': mainSets[group] ?? 0,
        'target': baseTarget * multiplier,
        'color': _groupColors[group] ?? Colors.white70,
        'exercises': mainExercises[group] ?? [],
      };
    }).toList();
  }

  void _setEmptyStatsState(TimeFilter filter, int multiplier) {
    if (!mounted) return;
    setState(() {
      _totalTonnage = 0.0;
      _completedSessionsCount = 0;
      _avgRpe = 0.0;
      _density = 0.0;

      if (filter == TimeFilter.month) {
        final now = DateTime.now();
        final emptyBars = _computeMonthlySplitBars(
          now: now,
          sets: [],
          sessionDateMap: {},
          weightUnit: _globalWeightUnit,
        );
        _volumeChartData = emptyBars;
        _volumeChartLabels = emptyBars.map((b) => b.label).toList();
      } else {
        final emptyVolume = _computeStandardVolumeChartData(
          volumeBucket: {},
          filter: filter,
        );
        _volumeChartData = emptyVolume['data'];
        _volumeChartLabels = emptyVolume['labels'];
      }

      _muscleData = _buildMuscleSplitData(
        mainSets: {},
        mainExercises: {},
        multiplier: multiplier,
      );
      _isLoading = false;
    });
  }

  // =========================================================================
  // CARICAMENTO INIZIALE Esercizi Compound con Calcolo PR Reale
  // =========================================================================
  Future<void> _loadExercisesAndStats() async {
    if (widget.isar == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _globalWeightUnit = prefs.getString('global_weight_unit') ?? 'kg';
    final saved1RmExercise = prefs.getString('last_selected_1rm_exercise');

    final dbExercises =
        await widget.isar!.exercises.filter().isCompoundEqualTo(true).findAll();

    List<CompoundExerciseInfo> loadedCompounds = [];

    if (dbExercises.isNotEmpty) {
      for (var ex in dbExercises) {
        final sets =
            await widget.isar!.workoutSets
                .filter()
                .exercise((q) => q.nameEqualTo(ex.name, caseSensitive: false))
                .and()
                .isWarmupEqualTo(false)
                .findAll();

        double maxPr = 0.0;
        for (final s in sets) {
          double w = s.weight;
          if (_globalWeightUnit == 'lbs') w *= 2.20462;
          final double oneRm = calculateSetScore(s, w);
          if (oneRm > maxPr) maxPr = oneRm;
        }

        loadedCompounds.add(
          CompoundExerciseInfo(
            name: ex.name,
            muscle: '${ex.muscleGroup} • ${ex.equipment ?? "Multiarticolare"}',
            icon: Icons.fitness_center_rounded,
            pr: double.parse(maxPr.toStringAsFixed(1)),
            imagePath: ex.imagePath,
          ),
        );
      }
    } else {
      loadedCompounds = [
        const CompoundExerciseInfo(
          name: 'Panca Piana Bilanciere',
          muscle: 'Petto • Bilanciere',
          icon: Icons.fitness_center_rounded,
          pr: 100.0,
        ),
      ];
    }

    if (loadedCompounds.any((e) => e.name == _selectedExercise)) {
      // Mantieni l'esercizio corrente
    } else if (saved1RmExercise != null &&
        loadedCompounds.any((e) => e.name == saved1RmExercise)) {
      _selectedExercise = saved1RmExercise;
    } else {
      _selectedExercise = loadedCompounds.first.name;
    }

    _compoundList = loadedCompounds;
    await _fetchDatabaseStats();
  }

  // =========================================================================
  // FETCH STATISTICHE E AGGREGAZIONE DATI (Ottimizzato e Modulare)
  // =========================================================================
  Future<void> _fetchDatabaseStats() async {
    if (widget.isar == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    DateTime queryStartDate = _calculateCalendarStartDate(now, _selectedFilter);
    final int multiplier =
        _selectedFilter == TimeFilter.week
            ? 1
            : (_selectedFilter == TimeFilter.month ? 4 : 48);

    // Se siamo nel mese, allarghiamo l'intervallo di query al primo lunedì per
    // includere la porzione del mese precedente nelle barre sdoppiate
    if (_selectedFilter == TimeFilter.month) {
      final firstDay = DateTime(now.year, now.month, 1);
      queryStartDate = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    }

    final sessions =
        await widget.isar!.sessions
            .filter()
            .dateGreaterThan(
              queryStartDate.subtract(const Duration(seconds: 1)),
            )
            .and()
            .dateLessThan(now.add(const Duration(days: 7)))
            .findAll();

    if (sessions.isEmpty) {
      _setEmptyStatsState(_selectedFilter, multiplier);
      return;
    }

    final Map<Id, DateTime> sessionDateMap = {
      for (final s in sessions) s.id: s.date,
    };

    // Filtriamo le sessioni del mese/periodo stretto per calcolare sessioni e durata KPI
    final strictStartDate = _calculateCalendarStartDate(now, _selectedFilter);
    final strictPeriodSessions =
        sessions.where((s) {
          return !s.date.isBefore(strictStartDate) &&
              !s.date.isAfter(now.add(const Duration(days: 1)));
        }).toList();

    int totalMinutes = 0;
    for (final s in strictPeriodSessions) {
      if (s.endTime != null) {
        totalMinutes += s.endTime!.difference(s.startTime).inMinutes;
      }
    }

    final allSets =
        await widget.isar!.workoutSets
            .filter()
            .session(
              (q) => q
                  .dateGreaterThan(
                    queryStartDate.subtract(const Duration(seconds: 1)),
                  )
                  .and()
                  .dateLessThan(now.add(const Duration(days: 7))),
            )
            .findAll();

    await Future.wait([
      for (final s in allSets) ...[
        if (!s.session.isLoaded) s.session.load(),
        if (!s.exercise.isLoaded) s.exercise.load(),
      ],
    ]);

    double localTonnage = 0.0;
    double localRpeSum = 0.0;
    int localRpeCount = 0;
    final Map<int, double> localVolumeBucket = {};

    final Map<String, int> localMainSets = {for (final g in _muscleOrder) g: 0};
    final Map<String, List<Map<String, dynamic>>> localMainExercises = {
      for (final g in _muscleOrder) g: [],
    };

    for (final s in allSets) {
      if (s.isWarmup) continue;

      final sId = s.session.value?.id;
      final sDate = sId != null ? sessionDateMap[sId] : null;
      if (sDate == null) continue;

      double weight = s.weight;
      if (_globalWeightUnit == 'lbs') weight *= 2.20462;
      final int reps = s.reps ?? 1;
      final double setVol = weight * reps;

      // Il tonnellaggio KPI conta SOLO i set del periodo selezionato stretto
      final bool isInsideStrictPeriod =
          !sDate.isBefore(strictStartDate) &&
          !sDate.isAfter(now.add(const Duration(days: 1)));

      if (isInsideStrictPeriod) {
        localTonnage += setVol;
        if (s.rpe != null && s.rpe! > 0) {
          localRpeSum += s.rpe!;
          localRpeCount++;
        }
      }

      // Raggruppamento Volume per Settimana / Anno
      if (_selectedFilter != TimeFilter.month && isInsideStrictPeriod) {
        final key = _calculateVolumeBucketKey(sDate, _selectedFilter);
        localVolumeBucket[key] = (localVolumeBucket[key] ?? 0.0) + setVol;
      }

      // Hard Sets (conteggiati solo nel periodo stretto)
      if (isInsideStrictPeriod && s.rpe != null && s.rpe! >= 8) {
        final ex = s.exercise.value;
        if (ex != null) {
          final mainGroup = _getMainMuscleGroup(ex.muscleGroup);
          if (localMainSets.containsKey(mainGroup)) {
            localMainSets[mainGroup] = localMainSets[mainGroup]! + 1;

            final exerciseList = localMainExercises[mainGroup]!;
            final existingIndex = exerciseList.indexWhere(
              (e) => e['name'] == ex.name,
            );

            if (existingIndex != -1) {
              exerciseList[existingIndex]['sets'] =
                  (exerciseList[existingIndex]['sets'] as int) + 1;
            } else {
              exerciseList.add({
                'name': ex.name,
                'sets': 1,
                'reps': '$reps',
                'avgWeight': double.parse(weight.toStringAsFixed(1)),
                'imagePath': ex.imagePath,
              });
            }
          }
        }
      }
    }

    // Risoluzione Grafico Volume (Split Barre per il Mese, Standard per Settimana/Anno)
    List<dynamic> computedVolumeData;
    List<String> computedVolumeLabels;

    if (_selectedFilter == TimeFilter.month) {
      final splitBars = _computeMonthlySplitBars(
        now: now,
        sets: allSets,
        sessionDateMap: sessionDateMap,
        weightUnit: _globalWeightUnit,
      );
      computedVolumeData = splitBars;
      computedVolumeLabels = splitBars.map((b) => b.label).toList();
    } else {
      final stdVolume = _computeStandardVolumeChartData(
        volumeBucket: localVolumeBucket,
        filter: _selectedFilter,
      );
      computedVolumeData = stdVolume['data'];
      computedVolumeLabels = stdVolume['labels'];
    }

    final computedMuscleData = _buildMuscleSplitData(
      mainSets: localMainSets,
      mainExercises: localMainExercises,
      multiplier: multiplier,
    );

    if (mounted) {
      setState(() {
        _totalTonnage = localTonnage;
        _completedSessionsCount = strictPeriodSessions.length;
        _avgRpe = localRpeCount > 0 ? (localRpeSum / localRpeCount) : 0.0;
        _density = totalMinutes > 0 ? (localTonnage / totalMinutes) : 0.0;
        _volumeChartData = computedVolumeData;
        _volumeChartLabels = computedVolumeLabels;
        _muscleData = computedMuscleData;
        _isLoading = false;
      });
    }
  }

  // =========================================================================
  // WIDGET UI: KPI GRID
  // =========================================================================
  Widget _buildKpiGrid() {
    String tonnageVal;
    if (_totalTonnage >= 1000000) {
      tonnageVal = '${(_totalTonnage / 1000000).toStringAsFixed(2)}M';
    } else if (_totalTonnage >= 1000) {
      tonnageVal = '${(_totalTonnage / 1000).toStringAsFixed(1)}k';
    } else {
      tonnageVal = _totalTonnage.toStringAsFixed(0);
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(
                title: 'Tonnellaggio',
                value: tonnageVal,
                unit: _globalWeightUnit,
                icon: Icons.fitness_center_rounded,
                iconColor: const Color(0xFFFF9700),
                variation: 'Dati reali',
              ),
              const SizedBox(height: 12),
              _buildMetricCard(
                title: 'RPE Medio',
                value: _avgRpe > 0 ? _avgRpe.toStringAsFixed(1) : '-',
                unit: '/ 10',
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFFFFB74D),
                variation: _avgRpe >= 8.0 ? 'Alta Intensità' : 'Moderata',
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(
                title: 'Sessioni',
                value: '$_completedSessionsCount',
                unit: 'registrate',
                icon: Icons.check_circle_outline_rounded,
                iconColor: Colors.white,
                variation: 'Nel periodo',
              ),
              const SizedBox(height: 12),
              _buildMetricCard(
                title: 'Densità',
                value: _density > 0 ? _density.toStringAsFixed(0) : '-',
                unit: '$_globalWeightUnit/min',
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFFE65100),
                variation: 'Volume / Tempo',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required String variation,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            variation,
            style: const TextStyle(
              color: Color(0xFFFF9700),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // WIDGET UI: SELETTORE TEMPORALE ANIMATO
  // =========================================================================
  Widget _buildTimeFilterSelector() {
    Alignment pillAlignment = Alignment.centerLeft;
    if (_selectedFilter == TimeFilter.month) {
      pillAlignment = Alignment.center;
    } else if (_selectedFilter == TimeFilter.year) {
      pillAlignment = Alignment.centerRight;
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth = (constraints.maxWidth) / 3;

          return Stack(
            children: [
              AnimatedAlign(
                alignment: pillAlignment,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: itemWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9700),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9700).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _buildAnimatedFilterItem('Settimana', TimeFilter.week),
                  _buildAnimatedFilterItem('Mese', TimeFilter.month),
                  _buildAnimatedFilterItem('Anno', TimeFilter.year),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedFilterItem(String label, TimeFilter filter) {
    final bool isSelected = _selectedFilter == filter;
    final TextStyle baseStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _changeTimeFilter(filter),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            style: baseStyle.copyWith(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BUILD PRINCIPALE DELLA SCHERMATA
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final double topStartOpacity = (1.0 - (_topScrollOffset / 35.0)).clamp(
      0.0,
      1.0,
    );
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double cutOffBottom = (bottomInset - 20.0).clamp(0.0, 100.0);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Statistiche & Trend',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    color: Color(0xFFFF9700),
                    thickness: 3,
                    height: 1,
                  ),
                  const SizedBox(height: 14),
                  _buildTimeFilterSelector(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF9700),
                        ),
                      )
                      : Padding(
                        padding: EdgeInsets.only(bottom: cutOffBottom),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: topStartOpacity),
                                Colors.black,
                                Colors.black,
                              ],
                              stops: const [0.0, 0.04, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildKpiGrid(),
                                const SizedBox(height: 24),

                                // Card del Volume Sollevato con barre a 2 colori se Mese
                                VolumeTrendCard(
                                  data: _volumeChartData,
                                  labels: _volumeChartLabels,
                                  animation: _generalCurveAnimation,
                                  weightUnit: _globalWeightUnit,
                                ),
                                const SizedBox(height: 24),

                                // Card 1RM con Finestra Mobile
                                if (_compoundList.isNotEmpty &&
                                    _selectedExercise != null)
                                  OneRmProgressionCard(
                                    isar: widget.isar,
                                    compoundList: _compoundList,
                                    selectedExercise: _selectedExercise!,
                                    filter: _selectedFilter,
                                    animation: _oneRmCurveAnimation,
                                    onExerciseChanged: (newExercise) {
                                      setState(
                                        () => _selectedExercise = newExercise,
                                      );
                                      _oneRmAnimController.forward(from: 0.0);
                                    },
                                  ),
                                const SizedBox(height: 24),

                                // Card Trend Sovraccarico Progressivo con Finestra Mobile
                                ExerciseProgressCard(
                                  isar: widget.isar,
                                  filter: _selectedFilter,
                                ),
                                const SizedBox(height: 24),

                                // Card Hard Sets con tutti i 7 gruppi pre-popolati
                                MuscleSplitProgressCard(
                                  muscleData: _muscleData,
                                  animation: _generalCurveAnimation,
                                  weightUnit: _globalWeightUnit,
                                ),

                                const SizedBox(height: 65),
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
