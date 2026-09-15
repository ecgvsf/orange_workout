import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../models/stats_model.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../models/exercise.dart';
import 'ex_search_bar.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchReal1RmData();
  }

  @override
  void didUpdateWidget(covariant OneRmProgressionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter ||
        oldWidget.selectedExercise != widget.selectedExercise ||
        oldWidget.isar != widget.isar) {
      setState(() => _selected1RMIndex = -1);
      _fetchReal1RmData();
    }
  }

  Future<void> _fetchReal1RmData() async {
    if (widget.isar == null) {
      setState(() => _isLoading = false);
      return;
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

    // PR storico dell'esercizio
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

    double allTimeMax1Rm = 0.0;
    for (final s in allTimeSets) {
      if (s.reps > 0 && s.weight > 0) {
        final calc = s.weight * (1.0 + (0.0333 * s.reps));
        if (calc > allTimeMax1Rm) allTimeMax1Rm = calc;
      }
    }

    // Sessioni nel periodo
    final sessions =
        await widget.isar!.sessions
            .filter()
            .dateGreaterThan(startDate.subtract(const Duration(seconds: 1)))
            .and()
            .dateLessThan(now.add(const Duration(days: 1)))
            .sortByDate()
            .findAll();

    final List<Map<String, dynamic>> historyPoints = [];

    for (final session in sessions) {
      final setsInSession =
          await widget.isar!.workoutSets
              .filter()
              .session((q) => q.idEqualTo(session.id))
              .and()
              .exercise(
                (q) => q.nameEqualTo(
                  widget.selectedExercise,
                  caseSensitive: false,
                ),
              )
              .and()
              .isWarmupEqualTo(false)
              .findAll();

      double sessionBest1Rm = 0.0;
      for (final s in setsInSession) {
        if (s.reps > 0 && s.weight > 0) {
          final calc = s.weight * (1.0 + (0.0333 * s.reps));
          if (calc > sessionBest1Rm) sessionBest1Rm = calc;
        }
      }

      if (sessionBest1Rm > 0) {
        historyPoints.add({
          'date': _formatShortDate(session.date),
          'val': (sessionBest1Rm * 10).round() / 10,
        });
      }
    }

    if (mounted) {
      setState(() {
        _currentPr = (allTimeMax1Rm * 10).round() / 10;
        _realHistory = historyPoints;
        _isLoading = false;
      });
    }
  }

  String _formatShortDate(DateTime d) {
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

  Future<void> _showCompoundPickerModal() async {
    HapticFeedback.selectionClick();
    final sortedNames =
        widget.compoundList.map((e) => e.name).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (context) => ExerciseSearchPage(
              title: 'Multiarticolari (1RM)',
              items: sortedNames,
              selectedItem: widget.selectedExercise,
            ),
      ),
    );

    if (selected != null && selected != widget.selectedExercise) {
      setState(() => _selected1RMIndex = -1);
      widget.onExerciseChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<double> points =
        _realHistory.map<double>((e) => (e['val'] as num).toDouble()).toList();

    final CompoundExerciseInfo currentExercise = widget.compoundList.firstWhere(
      (e) => e.name == widget.selectedExercise,
      orElse:
          () =>
              widget.compoundList.isNotEmpty
                  ? widget.compoundList.first
                  : const CompoundExerciseInfo(
                    name: 'Esercizio',
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Progressione 1RM (Stima)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
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
                      ? 'PR: ${_currentPr.toStringAsFixed(1)} kg'
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

          // Selettore Multiarticolare con apertura ModalBottomSheet
          GestureDetector(
            onTap:
                widget.compoundList.isNotEmpty
                    ? _showCompoundPickerModal
                    : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      currentExercise.icon,
                      color: const Color(0xFFFF9700),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentExercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
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

          // Grafico 1RM o stato di caricamento
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
                      ? 'Nessun dato registrato per ${widget.selectedExercise}'
                      : 'Registra un\'altra sessione per vedere la curva',
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

                if (_selected1RMIndex >= 0 &&
                    _selected1RMIndex < points.length) {
                  final double minVal = points.reduce(min) - 5;
                  final double maxVal = points.reduce(max) + 5;
                  final double range =
                      (maxVal - minVal == 0) ? 1 : (maxVal - minVal);

                  final double pointX = _selected1RMIndex * dx;
                  final double normalized =
                      (points[_selected1RMIndex] - minVal) / range;
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
                        final double localX = details.localPosition.dx;
                        int closestIndex = (localX / dx).round().clamp(
                          0,
                          points.length - 1,
                        );
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
                              painter: _LineChartPainter(
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
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: 1.0,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${points[_selected1RMIndex].toStringAsFixed(1)} ',
                                      style: const TextStyle(
                                        color: Color(0xFFFF9700),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'kg 1RM',
                                      style: TextStyle(
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

class _LineChartPainter extends CustomPainter {
  final List<double> points;
  final int selectedIndex;
  final double animationProgress;

  _LineChartPainter({
    required this.points,
    this.selectedIndex = -1,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final double minVal = points.reduce(min) - 5;
    final double maxVal = points.reduce(max) + 5;
    final double range = (maxVal - minVal == 0) ? 1 : (maxVal - minVal);

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
              ).withValues(alpha: 0.35 * animationProgress),
              const Color(0xFFFF9700).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Paint dotPaint = Paint()..color = Colors.white;
    final Paint dotBorder =
        Paint()
          ..color = const Color(0xFFFF9700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final Paint selectedHaloPaint =
        Paint()
          ..color = const Color(0xFFFF9700).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

    final Paint selectedBorder =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;

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
        canvas.drawCircle(Offset(x, y), 12, selectedHaloPaint);
        canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()..color = const Color(0xFFFF9700),
        );
        canvas.drawCircle(Offset(x, y), 6, selectedBorder);
      } else {
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
        canvas.drawCircle(Offset(x, y), 4, dotBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.points != points;
}
