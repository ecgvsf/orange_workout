import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../models/stats_model.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../models/exercise.dart';

import '../widgets/stats/volume_trend_card.dart';
import '../widgets/stats/one_rm_progression_chart_card.dart';
import '../widgets/stats/exercise_session_data_card.dart';
import '../widgets/stats/muscle_split_progress_card.dart';

class StatsScreen extends StatefulWidget {
  final Isar? isar;

  const StatsScreen({super.key, this.isar});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  double _topScrollOffset = 0.0;

  @override
  bool get wantKeepAlive => true;

  StreamSubscription? _sessionSub;
  StreamSubscription? _setSub;

  late final AnimationController _generalAnimController;
  late final Animation<double> _generalCurveAnimation;

  late final AnimationController _oneRmAnimController;
  late final Animation<double> _oneRmCurveAnimation;

  TimeFilter _selectedFilter = TimeFilter.month;
  String _selectedExercise = 'Panca Piana Bilanciere';
  String _globalWeightUnit = 'kg';

  bool _isLoading = true;
  List<CompoundExerciseInfo> _compoundList = [];

  double _totalTonnage = 0.0;
  int _completedSessionsCount = 0;
  double _avgRpe = 0.0;
  double _density = 0.0;

  List<double> _volumeChartData = [];
  List<String> _volumeChartLabels = [];
  List<Map<String, dynamic>> _muscleData = [];

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
    if (widget.isar != null) {
      _sessionSub = widget.isar!.sessions.watchLazy().listen((_) {
        if (mounted) _loadExercisesAndStats();
      });
      _setSub = widget.isar!.workoutSets.watchLazy().listen((_) {
        if (mounted) _loadExercisesAndStats();
      });
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
    _sessionSub?.cancel();
    _setSub?.cancel();
    super.dispose();
  }

  void _changeTimeFilter(TimeFilter filter) {
    if (_selectedFilter == filter) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedFilter = filter);
    _loadExercisesAndStats();
    _generalAnimController.forward(from: 0.0);
    _oneRmAnimController.forward(from: 0.0);
  }

  // Mappatura accurata per distretti muscolari principali
  String _getMainMuscleGroup(String rawMuscle) {
    final lower = rawMuscle.toLowerCase().trim();
    if (lower.contains('petto') || lower.contains('chest')) return 'Petto';
    if (lower.contains('dorso') ||
        lower.contains('schiena') ||
        lower.contains('trapez') ||
        lower.contains('lats'))
      return 'Dorso';
    if (lower.contains('spall') || lower.contains('deltoid')) return 'Spalle';
    if (lower.contains('tricipit') || lower.contains('triceps'))
      return 'Tricipiti';
    if (lower.contains('bicipit') ||
        lower.contains('biceps') ||
        lower.contains('avambracc'))
      return 'Bicipiti';
    if (lower.contains('gambe') ||
        lower.contains('quad') ||
        lower.contains('femor') ||
        lower.contains('glute') ||
        lower.contains('polpacc') ||
        lower.contains('adduttor') ||
        lower.contains('abduttor') ||
        lower.contains('soleo') ||
        lower.contains('legs'))
      return 'Gambe';
    if (lower.contains('addom') ||
        lower.contains('core') ||
        lower.contains('lombari') ||
        lower.contains('abs') ||
        lower.contains('obliqu'))
      return 'Core';
    return 'Altro';
  }

  Future<void> _loadExercisesAndStats() async {
    if (widget.isar == null) {
      setState(() => _isLoading = false);
      return;
    }

    final dbExercises =
        await widget.isar!.exercises.filter().isCompoundEqualTo(true).findAll();

    List<CompoundExerciseInfo> loadedCompounds = [];

    if (dbExercises.isNotEmpty) {
      for (var ex in dbExercises) {
        loadedCompounds.add(
          CompoundExerciseInfo(
            name: ex.name,
            muscle: '${ex.muscleGroup} • ${ex.equipment ?? "Multiarticolare"}',
            icon: Icons.fitness_center_rounded,
            pr: 0.0,
            imagePath: ex.imagePath,
          ),
        );
      }
    } else {
      loadedCompounds = const [
        CompoundExerciseInfo(
          name: 'Panca Piana Bilanciere',
          muscle: 'Petto • Bilanciere',
          icon: Icons.fitness_center_rounded,
          pr: 100.0,
        ),
      ];
    }

    final prefs = await SharedPreferences.getInstance();
    final saved1RmExercise = prefs.getString('last_selected_1rm_exercise');
    _globalWeightUnit = prefs.getString('global_weight_unit') ?? 'kg';

    if (loadedCompounds.any((e) => e.name == _selectedExercise)) {
      // Mantiene l'esercizio corrente
    } else if (saved1RmExercise != null &&
        loadedCompounds.any((e) => e.name == saved1RmExercise)) {
      _selectedExercise = saved1RmExercise;
    } else {
      _selectedExercise = loadedCompounds.first.name;
    }

    if (mounted) {
      setState(() {
        _compoundList = loadedCompounds;
      });
    }

    await _fetchDatabaseStats();
  }

  Future<void> _fetchDatabaseStats() async {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedFilter) {
      case TimeFilter.week:
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        break;
      case TimeFilter.month:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case TimeFilter.year:
        startDate = DateTime(now.year, 1, 1);
        break;
    }

    const List muscleOrder = [
      'Petto',
      'Dorso',
      'Gambe',
      'Spalle',
      'Tricipiti',
      'Bicipiti',
      'Core',
    ];

    final sessions =
        await widget.isar!.sessions
            .filter()
            .dateGreaterThan(startDate.subtract(const Duration(seconds: 1)))
            .and()
            .dateLessThan(now.add(const Duration(days: 1)))
            .findAll();

    final sessionIds = sessions.map((s) => s.id).toSet();
    final Map<Id, DateTime> sessionDates = {
      for (final s in sessions) s.id: s.date,
    };

    int totalMinutes = 0;
    for (final s in sessions) {
      if (s.endTime != null) {
        totalMinutes += s.endTime!.difference(s.startTime).inMinutes;
      }
    }

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

    double tonnageAcc = 0.0;
    double rpeSum = 0.0;
    int rpeCount = 0;
    final Map<int, double> volumeBucket = {};

    final Map<String, int> mainSets = {
      'Petto': 0,
      'Dorso': 0,
      'Gambe': 0,
      'Spalle': 0,
      'Tricipiti': 0,
      'Bicipiti': 0,
      'Core': 0,
      'Altro': 0,
    };
    final Map<String, List<Map<String, dynamic>>> mainExercises = {
      'Petto': [],
      'Dorso': [],
      'Gambe': [],
      'Spalle': [],
      'Tricipiti': [],
      'Bicipiti': [],
      'Core': [],
      'Altro': [],
    };

    for (final s in allSets) {
      double weight = s.weight;
      if (_globalWeightUnit == 'lbs') weight *= 2.20462;

      final int reps = s.reps ?? 1;
      final int? rpe = s.rpe;
      final bool isWarmup = s.isWarmup;

      await s.exercise.load();
      await s.session.load();

      final exName = s.exercise.value?.name ?? 'Esercizio';
      final muscleGroup = s.exercise.value?.muscleGroup ?? 'Altro';
      final sessionId = s.session.value?.id;
      final sDate = sessionId != null ? sessionDates[sessionId] : null;

      if (!isWarmup) {
        final double setTonnage = weight * reps;
        tonnageAcc += setTonnage;

        if (rpe != null && rpe > 0) {
          rpeSum += rpe;
          rpeCount++;
        }

        if (sDate != null) {
          int key = 0;
          if (_selectedFilter == TimeFilter.week) {
            key = sDate.weekday - 1;
          } else if (_selectedFilter == TimeFilter.month) {
            key = ((sDate.day - 1) / 7).floor().clamp(0, 3);
          } else {
            key = sDate.month - 1;
          }
          volumeBucket[key] = (volumeBucket[key] ?? 0.0) + setTonnage;
        }

        if (rpe != null && rpe >= 8) {
          final mainGroup = _getMainMuscleGroup(muscleGroup);

          if (mainGroup != 'Altro') {
            mainSets[mainGroup] = mainSets[mainGroup]! + 1;

            final existingList = mainExercises[mainGroup]!;
            final existingIndex = existingList.indexWhere(
              (e) => e['name'] == exName,
            );

            if (existingIndex != -1) {
              existingList[existingIndex]['sets'] =
                  (existingList[existingIndex]['sets'] as int) + 1;
            } else {
              existingList.add({
                'name': exName,
                'sets': 1,
                'reps': '$reps',
                'avgWeight': double.parse(weight.toStringAsFixed(1)),
                'imagePath': s.exercise.value?.imagePath,
              });
            }
          }
        }
      }
    }

    List<double> computedVolumeData = [];
    List<String> computedVolumeLabels = [];

    if (_selectedFilter == TimeFilter.week) {
      computedVolumeLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
      computedVolumeData = List.generate(7, (i) => volumeBucket[i] ?? 0.0);
    } else if (_selectedFilter == TimeFilter.month) {
      computedVolumeLabels = ['Sett 1', 'Sett 2', 'Sett 3', 'Sett 4'];
      computedVolumeData = List.generate(4, (i) => volumeBucket[i] ?? 0.0);
    } else {
      computedVolumeLabels = [
        'G',
        'F',
        'M',
        'A',
        'M',
        'G',
        'L',
        'A',
        'S',
        'O',
        'N',
        'D',
      ];
      computedVolumeData = List.generate(12, (i) => volumeBucket[i] ?? 0.0);
    }

    int multiplier = 1;
    if (_selectedFilter == TimeFilter.month) multiplier = 4;
    if (_selectedFilter == TimeFilter.year) multiplier = 48;

    // Target fisiologici ottimali (MAV) per singolo distretto
    final Map<String, int> groupTargets = {
      'Petto': 16 * multiplier,
      'Dorso': 16 * multiplier,
      'Gambe': 18 * multiplier,
      'Spalle': 12 * multiplier,
      'Tricipiti': 10 * multiplier,
      'Bicipiti': 10 * multiplier,
      'Core': 8 * multiplier,
    };

    final Map<String, Color> groupColors = {
      'Petto': const Color(0xFFE65100),
      'Dorso': const Color(0xFFFF6F00),
      'Gambe': const Color(0xFFF57C00),
      'Spalle': const Color(0xFFFF9700),
      'Tricipiti': const Color(0xFFFFB74D),
      'Bicipiti': const Color(0xFFFFD54F),
      'Core': Colors.white,
    };

    final List<Map<String, dynamic>> computedMuscleData =
        mainSets.entries
            .where((entry) => entry.value > 0 && entry.key != 'Altro')
            .map((entry) {
              final group = entry.key;
              return {
                'muscle': group,
                'sets': entry.value,
                'target': groupTargets[group] ?? 12 * multiplier,
                'color': groupColors[group] ?? Colors.white70,
                'exercises': mainExercises[group] ?? [],
              };
            })
            .toList();

    computedMuscleData.sort((a, b) {
      final indexA = muscleOrder.indexOf(a['muscle']);
      final indexB = muscleOrder.indexOf(b['muscle']);

      // Se entrambi sono nella lista, rispettano l'ordine prestabilito
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      return 0;
    });

    if (mounted) {
      setState(() {
        _totalTonnage = tonnageAcc;
        _completedSessionsCount = sessions.length;
        _avgRpe = rpeCount > 0 ? (rpeSum / rpeCount) : 0.0;
        _density = totalMinutes > 0 ? (tonnageAcc / totalMinutes) : 0.0;
        _volumeChartData = computedVolumeData;
        _volumeChartLabels = computedVolumeLabels;
        _muscleData = computedMuscleData;
        _isLoading = false;
      });
    }
  }

  Widget _buildTimeFilterSelector() {
    Alignment pillAlignment = Alignment.center;
    if (_selectedFilter == TimeFilter.week) {
      pillAlignment = Alignment.centerLeft;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double topStartOpacity = (1.0 - (_topScrollOffset / 35.0)).clamp(
      0.0,
      1.0,
    );

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
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: topStartOpacity),
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.05, 0.93, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: RefreshIndicator(
                  color: const Color(0xFFFF9700),
                  backgroundColor: const Color(0xFF1E1E1E),
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    await _loadExercisesAndStats();
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0.0);
                    }
                    _generalAnimController.forward(from: 0.0);
                    _oneRmAnimController.forward(from: 0.0);
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiGrid(),
                        const SizedBox(height: 24),
                        VolumeTrendCard(
                          data:
                              _volumeChartData.isEmpty
                                  ? [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
                                  : _volumeChartData,
                          labels:
                              _volumeChartLabels.isEmpty
                                  ? [
                                    'Lun',
                                    'Mar',
                                    'Mer',
                                    'Gio',
                                    'Ven',
                                    'Sab',
                                    'Dom',
                                  ]
                                  : _volumeChartLabels,
                          animation: _generalCurveAnimation,
                          weightUnit: _globalWeightUnit,
                        ),
                        const SizedBox(height: 24),
                        OneRmProgressionCard(
                          isar: widget.isar,
                          compoundList: _compoundList,
                          selectedExercise: _selectedExercise,
                          filter: _selectedFilter,
                          animation: _oneRmCurveAnimation,
                          onExerciseChanged: (newExercise) async {
                            setState(() => _selectedExercise = newExercise);
                            _oneRmAnimController.forward(from: 0.0);

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              'last_selected_1rm_exercise',
                              newExercise,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        ExerciseProgressCard(
                          isar: widget.isar,
                          filter: _selectedFilter,
                        ),
                        const SizedBox(height: 24),
                        MuscleSplitProgressCard(
                          muscleData: _muscleData,
                          animation: _generalCurveAnimation,
                          weightUnit: _globalWeightUnit,
                        ),
                        // Margine aumentato per evitare sovrapposizione con la bottom nav bar
                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
