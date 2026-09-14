import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../models/stats_model.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../models/exercise.dart';

import '../widgets/volume_trend_card.dart';
import '../widgets/one_rm_progression_chart_card.dart';
import '../widgets/muscle_split_progress_card.dart';
import '../widgets/exercise_session_data_card.dart';

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
  String _selectedExercise = 'Panca Piana Bilanciere';
  bool _isLoading = true;

  // Dati Aggregati Reali
  double _totalTonnage = 0.0;
  int _completedSessionsCount = 0;
  double _avgRpe = 0.0;
  double _density = 0.0;

  List<double> _volumeChartData = [];
  List<String> _volumeChartLabels = [];

  List<Map<String, dynamic>> _oneRmHistory = [];
  List<Map<String, dynamic>> _muscleData = [];

  final List<CompoundExerciseInfo> _compoundList = const [
    CompoundExerciseInfo(
      name: 'Panca Piana Bilanciere',
      muscle: 'Petto • Push',
      icon: Icons.fitness_center_rounded,
      pr: 118.0,
    ),
    CompoundExerciseInfo(
      name: 'Squat Bilanciere',
      muscle: 'Gambe • Quad Focus',
      icon: Icons.accessibility_new_rounded,
      pr: 155.0,
    ),
    CompoundExerciseInfo(
      name: 'Stacco da Terra',
      muscle: 'Dorso / Femorali',
      icon: Icons.airline_seat_recline_extra_rounded,
      pr: 180.0,
    ),
    CompoundExerciseInfo(
      name: 'Trazioni alla Sbarra',
      muscle: 'Dorso • Lats',
      icon: Icons.sports_gymnastics_rounded,
      pr: 35.0,
    ),
    CompoundExerciseInfo(
      name: 'Military Press',
      muscle: 'Deltoidi • Spalle',
      icon: Icons.arrow_upward_rounded,
      pr: 72.5,
    ),
  ];

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

    _fetchDatabaseStats();
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
    super.dispose();
  }

  void _changeTimeFilter(TimeFilter filter) {
    if (_selectedFilter == filter) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFilter = filter;
    });
    _fetchDatabaseStats();
    _generalAnimController.forward(from: 0.0);
    _oneRmAnimController.forward(from: 0.0);
  }

  // --- QUERY ED ELABORAZIONE DATI ISAR ---
  Future<void> _fetchDatabaseStats() async {
    if (widget.isar == null) {
      setState(() => _isLoading = false);
      return;
    }

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

    // 1. Estrai le sessioni nel periodo
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

    // 2. Calcolo durata totale in minuti
    int totalMinutes = 0;
    for (final s in sessions) {
      if (s.endTime != null) {
        totalMinutes += s.endTime!.difference(s.startTime).inMinutes;
      }
    }

    // 3. Query diretta su WorkoutSet tramite link "session"
    final allSets =
        await widget.isar!.workoutSets
            .filter()
            .session(
              (q) => q
                  .dateGreaterThan(
                    startDate.subtract(const Duration(seconds: 1)),
                  )
                  .and()
                  .dateLessThan(now.add(const Duration(days: 1))),
            )
            .findAll();

    double tonnageAcc = 0.0;
    double rpeSum = 0.0;
    int rpeCount = 0;

    final Map<int, double> volumeBucket = {};
    final Map<String, List<Map<String, dynamic>>> muscleExercises = {
      'Petto (Push)': [],
      'Dorso (Pull)': [],
      'Quadricipiti (Legs)': [],
      'Femorali / Glutei': [],
      'Deltoidi': [],
      'Braccia (Bic/Tric)': [],
    };
    final Map<String, int> muscleSets = {
      'Petto (Push)': 0,
      'Dorso (Pull)': 0,
      'Quadricipiti (Legs)': 0,
      'Femorali / Glutei': 0,
      'Deltoidi': 0,
      'Braccia (Bic/Tric)': 0,
    };

    final Map<Id, double> sessionMax1RmMap = {};

    for (final s in allSets) {
      final double weight = s.weight;
      final int reps = s.reps;
      final int? rpe = s.rpe;
      final bool isWarmup = s.isWarmup;

      await s.exercise.load();
      await s.session.load();

      final exName = s.exercise.value?.name ?? '';
      final muscleGroup = s.exercise.value?.muscleGroup ?? '';
      final sessionId = s.session.value?.id;
      final sDate = sessionId != null ? sessionDates[sessionId] : null;

      if (!isWarmup) {
        final double setTonnage = weight * reps;
        tonnageAcc += setTonnage;

        if (rpe != null && rpe > 0) {
          rpeSum += rpe;
          rpeCount++;
        }

        // Calcolo volume bucket
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

        // Stima 1RM Brzycki per esercizio attivo
        if (exName.toLowerCase() == _selectedExercise.toLowerCase() &&
            reps > 0 &&
            sessionId != null) {
          final double calculated1Rm = weight * (1.0 + (0.0333 * reps));
          final double currentMax = sessionMax1RmMap[sessionId] ?? 0.0;
          if (calculated1Rm > currentMax) {
            sessionMax1RmMap[sessionId] = calculated1Rm;
          }
        }

        // Hard Sets (RPE >= 8)
        if (rpe != null && rpe >= 8) {
          final normalizedGroup = _normalizeMuscleGroup(muscleGroup, exName);
          if (muscleSets.containsKey(normalizedGroup)) {
            muscleSets[normalizedGroup] =
                (muscleSets[normalizedGroup] ?? 0) + 1;

            final existingList = muscleExercises[normalizedGroup]!;
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
                'avgWeight': weight,
              });
            }
          }
        }
      }
    }

    // 4. Costruzione punti 1RM ordinati
    final List<Map<String, dynamic>> calculatedOneRmList = [];
    final sortedSessionIds =
        sessionMax1RmMap.keys.toList()..sort(
          (a, b) => (sessionDates[a] ?? DateTime(2000)).compareTo(
            sessionDates[b] ?? DateTime(2000),
          ),
        );

    for (final sId in sortedSessionIds) {
      final date = sessionDates[sId];
      if (date != null) {
        calculatedOneRmList.add({
          'date': _formatShortDate(date),
          'val': (sessionMax1RmMap[sId]! * 10).round() / 10,
        });
      }
    }

    // 5. Configurazione assi grafico Volume
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

    // 6. Configurazione target Hard Sets
    int multiplier = 1;
    if (_selectedFilter == TimeFilter.month) multiplier = 4;
    if (_selectedFilter == TimeFilter.year) multiplier = 48;

    final List<Map<String, dynamic>> computedMuscleData = [
      {
        'muscle': 'Petto (Push)',
        'sets': muscleSets['Petto (Push)'] ?? 0,
        'target': 16 * multiplier,
        'color': const Color(0xFFFF9700),
        'exercises': muscleExercises['Petto (Push)'] ?? [],
      },
      {
        'muscle': 'Dorso (Pull)',
        'sets': muscleSets['Dorso (Pull)'] ?? 0,
        'target': 16 * multiplier,
        'color': const Color(0xFFFFB74D),
        'exercises': muscleExercises['Dorso (Pull)'] ?? [],
      },
      {
        'muscle': 'Quadricipiti (Legs)',
        'sets': muscleSets['Quadricipiti (Legs)'] ?? 0,
        'target': 14 * multiplier,
        'color': const Color(0xFFE65100),
        'exercises': muscleExercises['Quadricipiti (Legs)'] ?? [],
      },
      {
        'muscle': 'Femorali / Glutei',
        'sets': muscleSets['Femorali / Glutei'] ?? 0,
        'target': 12 * multiplier,
        'color': const Color(0xFFFF9700),
        'exercises': muscleExercises['Femorali / Glutei'] ?? [],
      },
      {
        'muscle': 'Deltoidi',
        'sets': muscleSets['Deltoidi'] ?? 0,
        'target': 12 * multiplier,
        'color': Colors.white70,
        'exercises': muscleExercises['Deltoidi'] ?? [],
      },
      {
        'muscle': 'Braccia (Bic/Tric)',
        'sets': muscleSets['Braccia (Bic/Tric)'] ?? 0,
        'target': 10 * multiplier,
        'color': const Color(0xFFFFB74D),
        'exercises': muscleExercises['Braccia (Bic/Tric)'] ?? [],
      },
    ];

    if (mounted) {
      setState(() {
        _totalTonnage = tonnageAcc;
        _completedSessionsCount = sessions.length;
        _avgRpe = rpeCount > 0 ? (rpeSum / rpeCount) : 0.0;
        _density = totalMinutes > 0 ? (tonnageAcc / totalMinutes) : 0.0;

        _volumeChartData = computedVolumeData;
        _volumeChartLabels = computedVolumeLabels;

        _oneRmHistory =
            calculatedOneRmList.isEmpty
                ? [
                  {'date': 'Oggi', 'val': 0.0},
                  {'date': 'Max', 'val': 0.0},
                ]
                : calculatedOneRmList;

        _muscleData = computedMuscleData;
        _isLoading = false;
      });
    }
  }

  String _normalizeMuscleGroup(String muscleGroup, String exerciseName) {
    final m = muscleGroup.toLowerCase();
    final e = exerciseName.toLowerCase();
    if (m.contains('petto') ||
        e.contains('panca') ||
        e.contains('dip') ||
        e.contains('croci')) {
      return 'Petto (Push)';
    }
    if (m.contains('dorso') ||
        e.contains('trazion') ||
        e.contains('remator') ||
        e.contains('pulley')) {
      return 'Dorso (Pull)';
    }
    if (m.contains('quad') || e.contains('squat') || e.contains('press')) {
      return 'Quadricipiti (Legs)';
    }
    if (m.contains('femor') ||
        m.contains('glute') ||
        e.contains('stacco') ||
        e.contains('thrust') ||
        e.contains('curl')) {
      return 'Femorali / Glutei';
    }
    if (m.contains('spall') ||
        m.contains('delt') ||
        e.contains('military') ||
        e.contains('alzate')) {
      return 'Deltoidi';
    }
    if (m.contains('bracc') ||
        m.contains('bic') ||
        m.contains('tric') ||
        e.contains('french') ||
        e.contains('pushdown')) {
      return 'Braccia (Bic/Tric)';
    }
    return 'Petto (Push)';
  }

  String _formatShortDate(DateTime d) {
    switch (d.weekday) {
      case DateTime.monday:
        return 'Lun';
      case DateTime.tuesday:
        return 'Mar';
      case DateTime.wednesday:
        return 'Mer';
      case DateTime.thursday:
        return 'Gio';
      case DateTime.friday:
        return 'Ven';
      case DateTime.saturday:
        return 'Sab';
      case DateTime.sunday:
        return 'Dom';
      default:
        return '${d.day}';
    }
  }

  // --- KPI CARDS SINTETICI ---
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
                unit: 'kg',
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
                unit: 'kg/min',
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

  // --- SELETTORE TEMPORALE CON TRANSIZIONE FLUIDA E FONT GLOBALE ---
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

  @override
  Widget build(BuildContext context) {
    final double topStartOpacity = (1.0 - (_topScrollOffset / 35.0)).clamp(
      0.0,
      1.0,
    );
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double cutOffBottom = bottomInset - 20.0;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. HEADER E FILTRI FISSI IN ALTO
            // ==========================================
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

            // ==========================================
            // 2. AREA SCORREVOLE (SENZA OMBRA IN BASSO)
            // ==========================================
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
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
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
                                ),
                                const SizedBox(height: 24),

                                OneRmProgressionCard(
                                  isar: widget.isar,
                                  compoundList: _compoundList,
                                  selectedExercise: _selectedExercise,
                                  filter: _selectedFilter,
                                  animation: _oneRmCurveAnimation,
                                  onExerciseChanged: (newExercise) {
                                    setState(
                                      () => _selectedExercise = newExercise,
                                    );
                                    _fetchDatabaseStats();
                                    _oneRmAnimController.forward(from: 0.0);
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
