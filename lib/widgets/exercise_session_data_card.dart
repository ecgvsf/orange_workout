import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../models/stats_model.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../models/exercise.dart';

class ExerciseSessionData {
  final String date;
  final double weight;
  final int reps;
  final int rpe;

  const ExerciseSessionData({
    required this.date,
    required this.weight,
    required this.reps,
    required this.rpe,
  });

  double get workloadScore => weight * reps;
}

class ExerciseProgressCard extends StatefulWidget {
  final Isar? isar;
  final TimeFilter filter;

  const ExerciseProgressCard({
    super.key,
    this.isar,
    this.filter = TimeFilter.week,
  });

  @override
  State<ExerciseProgressCard> createState() => _ExerciseProgressCardState();
}

class _ExerciseProgressCardState extends State<ExerciseProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _curveAnimation;

  int _selectedPointIndex = -1;
  String _selectedExercise = 'Alzate Laterali Cavi';

  List<String> _availableExercises = [];
  List<ExerciseSessionData> _realHistory = [];
  double _exercisePrWeight = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _curveAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
    _fetchDatabaseExerciseData();
  }

  @override
  void didUpdateWidget(covariant ExerciseProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter || oldWidget.isar != widget.isar) {
      setState(() => _selectedPointIndex = -1);
      _fetchDatabaseExerciseData();
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchDatabaseExerciseData() async {
    if (widget.isar == null) {
      setState(() => _isLoading = false);
      return;
    }

    // 1. Estrai la lista di tutti gli esercizi presenti nel DB
    final exercisesInDb = await widget.isar!.exercises.where().findAll();
    final exerciseNames = exercisesInDb.map((e) => e.name).toSet().toList();

    // Se il database non ha ancora esercizi creati, usa un catalogo di fallback
    final available =
        exerciseNames.isNotEmpty
            ? exerciseNames
            : [
              'Alzate Laterali Cavi',
              'Leg Extension',
              'Curl Bilanciere Sagomato',
              'Pushdown Cavo Corda',
              'Calf Machine Seduto',
              'Panca Piana Bilanciere',
              'Trazioni alla Sbarra',
            ];

    if (!available.contains(_selectedExercise)) {
      _selectedExercise = available.first;
    }

    final now = DateTime.now();
    DateTime startDate;

    switch (widget.filter) {
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

    // 2. Calcolo PR di peso assoluto per questo esercizio
    final allTimeSets =
        await widget.isar!.workoutSets
            .filter()
            .isWarmupEqualTo(false)
            .and()
            .exercise(
              (q) => q.nameEqualTo(_selectedExercise, caseSensitive: false),
            )
            .findAll();

    double maxWeight = 0.0;
    for (final s in allTimeSets) {
      if (s.weight > maxWeight) maxWeight = s.weight;
    }

    // 3. Estrai sessioni nel periodo
    final sessions =
        await widget.isar!.sessions
            .filter()
            .dateGreaterThan(startDate.subtract(const Duration(seconds: 1)))
            .and()
            .dateLessThan(now.add(const Duration(days: 1)))
            .sortByDate()
            .findAll();

    final List<ExerciseSessionData> historyPoints = [];

    for (final session in sessions) {
      final sets =
          await widget.isar!.workoutSets
              .filter()
              .session((q) => q.idEqualTo(session.id))
              .and()
              .exercise(
                (q) => q.nameEqualTo(_selectedExercise, caseSensitive: false),
              )
              .and()
              .isWarmupEqualTo(false)
              .findAll();

      if (sets.isEmpty) continue;

      // Trova il miglior set allenante (score carico x ripetizioni)
      WorkoutSet? bestSet;
      double bestScore = 0.0;

      for (final s in sets) {
        final score = s.weight * s.reps;
        if (score > bestScore) {
          bestScore = score;
          bestSet = s;
        }
      }

      if (bestSet != null) {
        historyPoints.add(
          ExerciseSessionData(
            date: _formatDate(session.date),
            weight: bestSet.weight,
            reps: bestSet.reps,
            rpe: bestSet.rpe ?? 8,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _availableExercises = available;
        _exercisePrWeight = maxWeight;
        _realHistory = historyPoints;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime d) {
    if (widget.filter == TimeFilter.week) {
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
      }
    }
    return '${d.day}/${d.month}';
  }

  String _calculateTrendLabel(List<ExerciseSessionData> list) {
    if (list.length < 2) return 'Inizio periodo';
    final firstScore = list.first.workloadScore;
    final lastScore = list.last.workloadScore;
    if (firstScore == 0) return 'Stabile (=)';
    final diff = ((lastScore - firstScore) / firstScore) * 100;

    if (diff > 3.0) return '+${diff.toStringAsFixed(1)}% Sovraccarico 🔥';
    if (diff < -3.0) return '${diff.toStringAsFixed(1)}% Calo Carico';
    return 'Stabile (=)';
  }

  Color _calculateTrendColor(List<ExerciseSessionData> list) {
    if (list.length < 2) return const Color(0xFFFF9700);
    final firstScore = list.first.workloadScore;
    final lastScore = list.last.workloadScore;
    if (lastScore > firstScore) return const Color(0xFFFF9700);
    if (lastScore < firstScore) return Colors.redAccent;
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    final history = _realHistory;
    final points = history.map((e) => e.workloadScore).toList();
    final trendLabel = _calculateTrendLabel(history);
    final trendColor = _calculateTrendColor(history);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trend Sovraccarico Esercizio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Monitoraggio set allenante (Peso × Reps)',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trendLabel,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Menu Dropdown per qualsiasi esercizio reale
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedExercise,
                isExpanded: true,
                itemHeight: null,
                dropdownColor: const Color(0xFF191919),
                borderRadius: BorderRadius.circular(20),
                icon: const Padding(
                  padding: EdgeInsets.only(right: 4.0),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFFF9700),
                    size: 26,
                  ),
                ),
                selectedItemBuilder: (context) {
                  return _availableExercises.map((name) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF9700,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.fitness_center_rounded,
                              color: Color(0xFFFF9700),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                items:
                    _availableExercises.map((name) {
                      final bool isSelected = name == _selectedExercise;
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF222222)
                                    : const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFFFF9700)
                                      : Colors.white.withValues(alpha: 0.05),
                              width: isSelected ? 1.2 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF9700,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.fitness_center_rounded,
                                  color: Color(0xFFFF9700),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? const Color(0xFFFF9700)
                                            : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_exercisePrWeight > 0 && isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'PR ${_exercisePrWeight.toStringAsFixed(1)} kg',
                                    style: const TextStyle(
                                      color: Color(0xFFFF9700),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedExercise = val;
                      _selectedPointIndex = -1;
                    });
                    _fetchDatabaseExerciseData();
                    _animController.forward(from: 0.0);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Grafico Spline Interattivo
          if (_isLoading)
            const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9700)),
              ),
            )
          else if (points.length < 2)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  points.isEmpty
                      ? 'Nessun dato registrato per $_selectedExercise'
                      : 'Registra un\'altra sessione per vedere il trend',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final double chartWidth = constraints.maxWidth;
                const double chartHeight = 160.0;
                final double dx =
                    points.length > 1 ? chartWidth / (points.length - 1) : 0.0;

                double popupLeft = 0.0;
                double popupTop = 0.0;

                if (_selectedPointIndex >= 0 &&
                    _selectedPointIndex < points.length) {
                  final double minVal = points.reduce(min) * 0.9;
                  final double maxVal = points.reduce(max) * 1.1;
                  final double range =
                      maxVal - minVal == 0 ? 1 : maxVal - minVal;

                  final double pointX = _selectedPointIndex * dx;
                  final double normalized =
                      (points[_selectedPointIndex] - minVal) / range;
                  final double pointY =
                      chartHeight - (normalized * chartHeight);

                  popupLeft = (pointX - 70).clamp(0.0, chartWidth - 140);
                  popupTop = (pointY - 70) < 0 ? (pointY + 12) : (pointY - 70);
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final double localX = details.localPosition.dx;
                        int closest = (localX / dx).round().clamp(
                          0,
                          points.length - 1,
                        );
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedPointIndex =
                              (_selectedPointIndex == closest) ? -1 : closest;
                        });
                      },
                      child: SizedBox(
                        height: chartHeight,
                        width: double.infinity,
                        child: AnimatedBuilder(
                          animation: _curveAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(chartWidth, chartHeight),
                              painter: _WorkloadChartPainter(
                                points: points,
                                selectedIndex: _selectedPointIndex,
                                animationProgress: _curveAnimation.value,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_selectedPointIndex >= 0 &&
                        _selectedPointIndex < history.length)
                      Positioned(
                        top: popupTop,
                        left: popupLeft,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: 1.0,
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141414),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFF9700),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      history[_selectedPointIndex].date,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap:
                                          () => setState(
                                            () => _selectedPointIndex = -1,
                                          ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white38,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${history[_selectedPointIndex].weight} kg × ${history[_selectedPointIndex].reps} reps',
                                  style: const TextStyle(
                                    color: Color(0xFFFF9700),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'RPE ${history[_selectedPointIndex].rpe} • Score: ${history[_selectedPointIndex].workloadScore.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Un andamento verso l\'alto indica sovraccarico progressivo riuscito',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkloadChartPainter extends CustomPainter {
  final List<double> points;
  final int selectedIndex;
  final double animationProgress;

  _WorkloadChartPainter({
    required this.points,
    this.selectedIndex = -1,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final double minVal = points.reduce(min) * 0.9;
    final double maxVal = points.reduce(max) * 1.1;
    final double range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final double dx = size.width / (points.length - 1);

    final Path path = Path();
    final Path fillPath = Path();

    final Paint linePaint =
        Paint()
          ..color = const Color(0xFFFF9700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round;

    final Paint fillPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(
                0xFFFF9700,
              ).withValues(alpha: 0.30 * animationProgress),
              const Color(0xFFFF9700).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < points.length; i++) {
      final double x = i * dx;
      final double normalized =
          ((points[i] - minVal) / range) * animationProgress;
      final double y = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final double prevX = (i - 1) * dx;
        final double prevNormalized =
            ((points[i - 1] - minVal) / range) * animationProgress;
        final double prevY = size.height - (prevNormalized * size.height);

        final double cX1 = prevX + (x - prevX) / 2;
        final double cY1 = prevY;
        final double cX2 = prevX + (x - prevX) / 2;
        final double cY2 = y;

        path.cubicTo(cX1, cY1, cX2, cY2, x, y);
        fillPath.cubicTo(cX1, cY1, cX2, cY2, x, y);
      }

      if (i == points.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final double x = i * dx;
      final double normalized =
          ((points[i] - minVal) / range) * animationProgress;
      final double y = size.height - (normalized * size.height);
      final bool isSelected = i == selectedIndex;

      if (isSelected) {
        canvas.drawCircle(
          Offset(x, y),
          12,
          Paint()
            ..color = const Color(0xFFFF9700).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()..color = const Color(0xFFFF9700),
        );
        canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      } else {
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white);
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()
            ..color = const Color(0xFFFF9700)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorkloadChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.points != points;
}
