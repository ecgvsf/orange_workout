import 'dart:math';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../../models/stats_model.dart';
import '../../models/exercise.dart';
import '../../models/workout_set.dart';
import '../../models/session.dart';
import '../exercise_filterable_list_view.dart';
import '../../utils/time_formatters.dart';

class ExerciseSessionData {
  final String date;
  final DateTime dateTime;
  final double score;
  final double weight;
  final int? reps;
  final int? holdSeconds;
  final int rpe;

  const ExerciseSessionData({
    required this.date,
    required this.dateTime,
    required this.score,
    required this.weight,
    this.reps,
    this.holdSeconds,
    required this.rpe,
  });

  double get workloadScore => score;
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
  String? _selectedExercise;
  String? _selectedExerciseImagePath;
  String _selectedExerciseSubtitle = '';

  String _weightUnit = 'kg'; // <-- Aggiunto per il tracciamento

  List<ExerciseSessionData> _realHistory = [];
  double _exercisePrWeight = 0.0;
  bool _isLoading = true;
  bool _isTimedExercise = false;

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
    if (oldWidget.filter != widget.filter) {
      setState(() => _selectedPointIndex = -1);
      _animController.forward(from: 0.0);
    }
    _fetchDatabaseExerciseData();
  }

  @override
  void disposeValidate() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double _calculateSetScore(WorkoutSet s, double weight) {
    if (s.holdSeconds != null && s.holdSeconds! > 0) {
      if (weight > 0) {
        return s.holdSeconds!.toDouble() * (1.0 + (weight / 30.0));
      }
      return s.holdSeconds!.toDouble();
    }

    final int reps = s.reps ?? 0;
    if (weight > 0) {
      return weight * (1.0 + (0.0333 * reps));
    }
    return reps.toDouble();
  }

  Future<void> _fetchDatabaseExerciseData() async {
    if (widget.isar == null) {
      setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _weightUnit = prefs.getString('global_weight_unit') ?? 'kg';

    final exercisesInDb = await widget.isar!.exercises.where().findAll();
    if (exercisesInDb.isEmpty) {
      if (mounted) {
        setState(() {
          _realHistory = [];
          _isLoading = false;
        });
      }
      return;
    }

    final savedExercise = prefs.getString('last_selected_progress_exercise');

    if (_selectedExercise == null) {
      if (savedExercise != null &&
          exercisesInDb.any((e) => e.name == savedExercise)) {
        _selectedExercise = savedExercise;
      } else {
        _selectedExercise = exercisesInDb.first.name;
      }
    } else if (!exercisesInDb.any((e) => e.name == _selectedExercise)) {
      _selectedExercise = exercisesInDb.first.name;
    }

    final currentExObj = exercisesInDb.firstWhere(
      (e) => e.name == _selectedExercise,
      orElse: () => exercisesInDb.first,
    );
    _selectedExerciseImagePath = currentExObj.imagePath;
    _selectedExerciseSubtitle = currentExObj.muscleGroup;

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

    final allSets =
        await widget.isar!.workoutSets
            .filter()
            .isWarmupEqualTo(false)
            .and()
            .exercise(
              (q) => q.nameEqualTo(_selectedExercise!, caseSensitive: false),
            )
            .findAll();

    double allTimeMaxWeight = 0.0;
    bool isTimed = false;

    final Map<DateTime, List<WorkoutSet>> setsByDay = {};

    for (final s in allSets) {
      if (s.holdSeconds != null && s.holdSeconds! > 0) isTimed = true;

      double convertedWeight = s.weight;
      if (_weightUnit == 'lbs') {
        convertedWeight *= 2.20462;
      }

      if (convertedWeight > allTimeMaxWeight)
        allTimeMaxWeight = convertedWeight;

      await s.session.load();
      final session = s.session.value;
      if (session == null) continue;

      final sessionDate = session.date;
      final dayKey = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
      );

      if (dayKey.isBefore(startDate) ||
          dayKey.isAfter(now.add(const Duration(days: 1)))) {
        continue;
      }

      setsByDay.putIfAbsent(dayKey, () => []).add(s);
    }

    final sortedDates = setsByDay.keys.toList()..sort();
    final List<ExerciseSessionData> historyPoints = [];

    for (final day in sortedDates) {
      final daySets = setsByDay[day]!;

      WorkoutSet? bestSet;
      double bestDayScore = 0.0;
      double bestSetWeight =
          0.0; // Teniamo traccia del peso convertito per il popup

      for (final s in daySets) {
        double w = s.weight;
        if (_weightUnit == 'lbs') w *= 2.20462;

        final score = _calculateSetScore(s, w);
        if (score >= bestDayScore) {
          bestDayScore = score;
          bestSet = s;
          bestSetWeight = w;
        }
      }

      if (bestSet != null) {
        historyPoints.add(
          ExerciseSessionData(
            date: _formatDate(day),
            dateTime: day,
            score: (bestDayScore * 10).round() / 10,
            weight: double.parse(
              bestSetWeight.toStringAsFixed(1),
            ), // Usiamo il peso convertito
            reps: bestSet.reps,
            holdSeconds: bestSet.holdSeconds,
            rpe: bestSet.rpe ?? 8,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isTimedExercise = isTimed;
        _exercisePrWeight = allTimeMaxWeight;
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

  Future<void> _showExercisePickerModal() async {
    if (widget.isar == null) return;
    HapticFeedback.selectionClick();

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Seleziona Esercizio',
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
                  isar: widget.isar!,
                  isCompoundOnly: false,
                  selectedExerciseName: _selectedExercise,
                  searchHint: 'Cerca esercizio per monitorare...',
                  onExerciseTap: (exercise) {
                    HapticFeedback.selectionClick();
                    Navigator.pop(ctx, exercise.name);
                  },
                  trailingBuilder: (context, exercise, isSelected) {
                    return isSelected
                        ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFFF9700),
                          size: 22,
                        )
                        : null;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _selectedExercise) {
      setState(() {
        _selectedExercise = selected;
        _selectedPointIndex = -1;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_selected_progress_exercise', selected);
      _fetchDatabaseExerciseData();
      _animController.forward(from: 0.0);
    }
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trend Sovraccarico Esercizio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isTimedExercise
                        ? 'Monitoraggio intensità (Tempo + Peso)'
                        : 'Monitoraggio set allenante (Peso × Reps)',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
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

          GestureDetector(
            onTap: _showExercisePickerModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildThumbnail(_selectedExerciseImagePath),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedExercise ?? 'Nessun esercizio',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_selectedExerciseSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _selectedExerciseSubtitle,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_exercisePrWeight > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PR ${_exercisePrWeight.toStringAsFixed(1)} $_weightUnit', // Cambiato
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFFF9700),
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          if (_isLoading)
            const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9700)),
              ),
            )
          else if (points.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'Nessun dato registrato per ${_selectedExercise ?? "questo esercizio"}',
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
                final bool isSinglePoint = points.length == 1;
                final double dx =
                    !isSinglePoint ? chartWidth / (points.length - 1) : 0.0;

                double popupLeft = 0.0;
                double popupTop = 0.0;

                if (_selectedPointIndex >= 0 &&
                    _selectedPointIndex < points.length) {
                  final double minVal = points.reduce(min) * 0.9;
                  final double maxVal = points.reduce(max) * 1.1;
                  final double range =
                      maxVal - minVal == 0 ? 1 : maxVal - minVal;

                  final double pointX =
                      isSinglePoint ? chartWidth / 2 : _selectedPointIndex * dx;
                  final double normalized =
                      isSinglePoint
                          ? 0.5
                          : (points[_selectedPointIndex] - minVal) / range;
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
                        int closest = 0;
                        if (!isSinglePoint) {
                          final double localX = details.localPosition.dx;
                          closest = (localX / dx).round().clamp(
                            0,
                            points.length - 1,
                          );
                        }
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
                                  history[_selectedPointIndex].holdSeconds !=
                                          null
                                      ? '${history[_selectedPointIndex].weight > 0 ? "${history[_selectedPointIndex].weight} $_weightUnit × " : ""}${formatTimeSeconds(history[_selectedPointIndex].holdSeconds!)}'
                                      : '${history[_selectedPointIndex].weight} $_weightUnit × ${history[_selectedPointIndex].reps} reps',
                                  style: const TextStyle(
                                    color: Color(0xFFFF9700),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
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
    if (points.isEmpty) return;

    if (points.length == 1) {
      final double x = size.width / 2;
      final double y = size.height / 2;
      final bool isSelected = selectedIndex == 0;

      final Paint guidePaint =
          Paint()
            ..color = const Color(0xFFFF9700).withValues(alpha: 0.15)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;

      const double dashWidth = 5.0;
      const double dashSpace = 4.0;
      double startX = 16.0;
      while (startX < size.width - 16.0) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          guidePaint,
        );
        startX += dashWidth + dashSpace;
      }

      if (isSelected) {
        canvas.drawCircle(
          Offset(x, y),
          14 * animationProgress,
          Paint()
            ..color = const Color(0xFFFF9700).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x, y),
          6 * animationProgress,
          Paint()..color = const Color(0xFFFF9700),
        );
        canvas.drawCircle(
          Offset(x, y),
          6 * animationProgress,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          5 * animationProgress,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(x, y),
          5 * animationProgress,
          Paint()
            ..color = const Color(0xFFFF9700)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
      return;
    }

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

Widget _buildThumbnail(String? path) {
  const fallback = Icon(
    Icons.fitness_center_rounded,
    color: Color(0xFFFF9700),
    size: 24,
  );

  if (path == null || path.trim().isEmpty) return fallback;

  if (path.startsWith('assets/')) {
    final normalized = path
        .replaceAll('_start.', '-start.')
        .replaceAll('_peak.', '-peak.')
        .replaceAll('_main.', '-main.');
    return Image.asset(
      normalized,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  final file = File(path);
  if (file.existsSync()) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  return fallback;
}
