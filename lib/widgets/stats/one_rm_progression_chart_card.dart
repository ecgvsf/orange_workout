import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:orange_workout/models/exercise.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/stats_model.dart';
import '../../models/workout_set.dart';
import '../exercise_filterable_list_view.dart';
import '../../utils/time_formatters.dart';
import 'stats_chart_utils.dart';

class OneRmProgressionCard extends StatefulWidget {
  final Isar? isar;
  final List<CompoundExerciseInfo> compoundList;
  final String selectedExercise;
  final TimeFilter filter;
  final Animation<double> animation;
  final ValueChanged<String> onExerciseChanged;

  const OneRmProgressionCard({
    super.key,
    this.isar,
    required this.compoundList,
    required this.selectedExercise,
    required this.filter,
    required this.animation,
    required this.onExerciseChanged,
  });

  @override
  State<OneRmProgressionCard> createState() => _OneRmProgressionCardState();
}

class _OneRmProgressionCardState extends State<OneRmProgressionCard> {
  int _selected1RMIndex = -1;
  double _currentPr = 0.0;
  List<Map<String, dynamic>> _realHistory = [];
  bool _isLoading = true;
  bool _isTimedExercise = false;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _fetchReal1RmData();
  }

  @override
  void didUpdateWidget(covariant OneRmProgressionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter ||
        oldWidget.selectedExercise != widget.selectedExercise) {
      setState(() => _selected1RMIndex = -1);
    }
    _fetchReal1RmData();
  }

  Future<void> _fetchReal1RmData() async {
    if (widget.isar == null || widget.selectedExercise.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _weightUnit = prefs.getString('global_weight_unit') ?? 'kg';

    final now = DateTime.now();
    final startDate = calculateRollingStartDate(now, widget.filter);
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final allTimeSets =
        await widget.isar!.workoutSets
            .filter()
            .isWarmupEqualTo(false)
            .and()
            .exercise(
              (q) =>
                  q.nameEqualTo(widget.selectedExercise, caseSensitive: false),
            )
            .findAll();

    await Future.wait([
      for (final s in allTimeSets)
        if (!s.session.isLoaded) s.session.load(),
    ]);

    double allTimeMax = 0.0;
    bool isTimed = false;

    for (final s in allTimeSets) {
      if (s.holdSeconds != null && s.holdSeconds! > 0) isTimed = true;

      double w = s.weight;
      if (_weightUnit == 'lbs') w *= 2.20462;

      final score = calculateSetScore(s, w);
      if (score > allTimeMax) allTimeMax = score;
    }

    final setsByDay = filterAndGroupSetsByDay(
      sets: allTimeSets,
      startDate: startDate,
      endDate: endDate,
    );

    final sortedDates = setsByDay.keys.toList()..sort();
    final List<Map<String, dynamic>> historyPoints = [];

    for (final day in sortedDates) {
      double dayBest = 0.0;
      for (final s in setsByDay[day]!) {
        double w = s.weight;
        if (_weightUnit == 'lbs') w *= 2.20462;

        final score = calculateSetScore(s, w);
        if (score > dayBest) dayBest = score;
      }

      if (dayBest > 0) {
        historyPoints.add({
          'date': formatShortDate(day, widget.filter),
          'val': (dayBest * 10).round() / 10,
        });
      }
    }

    if (mounted) {
      setState(() {
        _isTimedExercise = isTimed;
        _currentPr = (allTimeMax * 10).round() / 10;
        _realHistory = historyPoints;
        _isLoading = false;
      });
    }
  }

  Future<void> _showCompoundPickerModal() async {
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
                  selectedExerciseName: widget.selectedExercise,
                  searchHint: 'Cerca esercizio...',
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

    if (selected != null && selected != widget.selectedExercise) {
      setState(() => _selected1RMIndex = -1);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_selected_1rm_exercise', selected);

      widget.onExerciseChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<double> points =
        _realHistory.map<double>((e) => (e['val'] as num).toDouble()).toList();
    final unitLabel = _isTimedExercise ? 's' : '$_weightUnit 1RM';

    final CompoundExerciseInfo currentExercise = widget.compoundList.firstWhere(
      (e) => e.name.toLowerCase() == widget.selectedExercise.toLowerCase(),
      orElse:
          () =>
              widget.compoundList.isNotEmpty
                  ? widget.compoundList.first
                  : CompoundExerciseInfo(
                    name:
                        widget.selectedExercise.isNotEmpty
                            ? widget.selectedExercise
                            : 'Esercizio',
                    muscle: '',
                    icon: Icons.fitness_center_rounded,
                    pr: 0.0,
                  ),
    );

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
                  Text(
                    _isTimedExercise
                        ? 'Progressione Tempo (Stima)'
                        : 'Progressione 1RM (Stima)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tocca un punto del grafico',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentPr > 0
                      ? 'PR: ${_isTimedExercise ? formatTimeSeconds(_currentPr.round()) : "${_currentPr.toStringAsFixed(1)} $_weightUnit"}'
                      : 'Nessun PR',
                  style: const TextStyle(
                    color: Color(0xFFFF9700),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          GestureDetector(
            onTap: _showCompoundPickerModal,
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
                      child: buildExerciseThumbnail(currentExercise.imagePath),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentExercise.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentExercise.muscle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            currentExercise.muscle,
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
                  'Nessun dato registrato per ${widget.selectedExercise}',
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

                if (_selected1RMIndex >= 0 &&
                    _selected1RMIndex < points.length) {
                  final double minVal = points.reduce(min) * 0.9;
                  final double maxVal = points.reduce(max) * 1.1;
                  final double range =
                      (maxVal - minVal == 0) ? 1 : (maxVal - minVal);

                  final double pointX =
                      isSinglePoint ? chartWidth / 2 : _selected1RMIndex * dx;
                  final double normalized =
                      isSinglePoint
                          ? 0.5
                          : (points[_selected1RMIndex] - minVal) / range;
                  final double pointY =
                      chartHeight - (normalized * chartHeight);

                  popupLeft = (pointX - 65).clamp(0.0, chartWidth - 130);
                  popupTop = (pointY - 65) < 0 ? (pointY + 12) : (pointY - 65);
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        int closestIndex = 0;
                        if (!isSinglePoint) {
                          final double localX = details.localPosition.dx;
                          closestIndex = (localX / dx).round().clamp(
                            0,
                            points.length - 1,
                          );
                        }
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selected1RMIndex =
                              (_selected1RMIndex == closestIndex)
                                  ? -1
                                  : closestIndex;
                        });
                      },
                      child: SizedBox(
                        height: chartHeight,
                        width: double.infinity,
                        child: AnimatedBuilder(
                          animation: widget.animation,
                          builder: (context, child) {
                            return CustomPaint(
                              size: Size(chartWidth, chartHeight),
                              painter: GenericLineChartPainter(
                                points: points,
                                selectedIndex: _selected1RMIndex,
                                animationProgress: widget.animation.value,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_selected1RMIndex >= 0 &&
                        _selected1RMIndex < points.length)
                      Positioned(
                        top: popupTop,
                        left: popupLeft,
                        child: Container(
                          width: 130,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
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
                                    _realHistory[_selected1RMIndex]['date'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap:
                                        () => setState(
                                          () => _selected1RMIndex = -1,
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _isTimedExercise
                                        ? '${formatTimeSeconds(points[_selected1RMIndex].round())} '
                                        : '${points[_selected1RMIndex].toStringAsFixed(1)} ',
                                    style: const TextStyle(
                                      color: Color(0xFFFF9700),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    unitLabel,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
              'Formula Brzycki: Carico × (1 + 0.0333 × Reps)',
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
