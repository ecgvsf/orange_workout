import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import '../models/exercise.dart';
import '../models/session.dart';
import '../models/workout_set.dart';

enum ChartMetricType { estimated1RM, maxWeight, totalVolume }

class ExerciseDetailStatsScreen extends StatefulWidget {
  final Isar? isar;
  final String exerciseName;
  final String muscleGroup;
  final String? imagePath;

  const ExerciseDetailStatsScreen({
    super.key,
    this.isar,
    required this.exerciseName,
    required this.muscleGroup,
    this.imagePath,
  });

  @override
  State<ExerciseDetailStatsScreen> createState() =>
      _ExerciseDetailStatsScreenState();
}

/// Modello interno arricchito per la singola sessione dell'esercizio
class _ExerciseSessionHistory {
  final DateTime date;
  final double maxWeight;
  final double estimated1RM;
  final double volume;
  final int totalSets;
  final int hardSetsCount;
  final WorkoutSet? bestSet;
  final List<WorkoutSet> sets;
  final bool isPersonalRecord;

  const _ExerciseSessionHistory({
    required this.date,
    required this.maxWeight,
    required this.estimated1RM,
    required this.volume,
    required this.totalSets,
    required this.hardSetsCount,
    required this.bestSet,
    required this.sets,
    required this.isPersonalRecord,
  });
}

class _ExerciseDetailStatsScreenState extends State<ExerciseDetailStatsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;

  // Statistiche All-Time (KPI)
  double _allTimeMaxWeight = 0.0;
  double _allTimeMax1RM = 0.0;
  double _allTimeVolume = 0.0;
  int _totalSetsAllTime = 0;
  int _totalHardSetsAllTime = 0;

  // Trend calcolato
  double _progressPercentage = 0.0; // Confronto prima e ultima sessione

  List<_ExerciseSessionHistory> _history = [];
  int _selectedPointIndex = -1;
  ChartMetricType _selectedMetric = ChartMetricType.estimated1RM;

  late final AnimationController _animController;
  late final Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _chartAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadExerciseData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Stima 1RM con formula di Brzycki / Epley calibrata per sicurezza sulle rep elevate
  double _calculate1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return weight;
    if (reps == 1) return weight;
    // Oltre le 12 ripetizioni l'affidabilità cala: applichiamo un cap empirico
    final int effectiveReps = reps.clamp(1, 12);
    // Formula di Brzycki: W * (36 / (37 - reps)) o Epley: W * (1 + 0.0333 * reps)
    return weight * (1.0 + (0.0333 * effectiveReps));
  }

  Future<void> _loadExerciseData() async {
    if (widget.isar == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final sets = await widget.isar!.workoutSets
          .filter()
          .exercise((q) => q.nameEqualTo(widget.exerciseName))
          .findAll();

      if (sets.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Raggruppa per sessione
      final Map<Id, List<WorkoutSet>> sessionMap = {};
      final Map<Id, DateTime> sessionDateMap = {};

      for (final s in sets) {
        await s.session.load();
        final session = s.session.value;
        if (session != null) {
          sessionMap.putIfAbsent(session.id, () => []).add(s);
          sessionDateMap[session.id] = session.date;
        }
      }

      final List<_ExerciseSessionHistory> historyList = [];
      double overallMaxWeight = 0.0;
      double overallMax1RM = 0.0;
      double overallVolume = 0.0;
      int totalHardSets = 0;

      // Primo passaggio: estrazione cronologica e calcolo valori
      final sortedEntries = sessionMap.entries.toList()
        ..sort((a, b) {
          final dateA = sessionDateMap[a.key] ?? DateTime(2000);
          final dateB = sessionDateMap[b.key] ?? DateTime(2000);
          return dateA.compareTo(dateB);
        });

      double runningMax1RM = 0.0;

      for (final entry in sortedEntries) {
        final date = sessionDateMap[entry.key] ?? DateTime.now();
        final sessionSets = entry.value;

        double sessionMaxW = 0.0;
        double sessionMax1RM = 0.0;
        double sessionVol = 0.0;
        int hardSets = 0;
        WorkoutSet? bestSet;
        double bestSetWorkload = -1.0;

        for (final set in sessionSets) {
          final w = set.weight.toDouble();
          final r = set.reps ?? 0;
          final rpe = set.rpe ?? 8;
          final isWarmup = set.isWarmup ?? false;

          if (!isWarmup) {
            sessionVol += (w * (r > 0 ? r : 1));
            if (rpe >= 7.5 || r >= 5) hardSets++;
          }

          if (w > sessionMaxW) sessionMaxW = w;

          final est1RM = _calculate1RM(w, r);
          if (est1RM > sessionMax1RM) sessionMax1RM = est1RM;

          final currentWorkload = w * r;
          if (currentWorkload > bestSetWorkload) {
            bestSetWorkload = currentWorkload;
            bestSet = set;
          }
        }

        final bool isPr = sessionMax1RM > runningMax1RM && runningMax1RM > 0;
        if (sessionMax1RM > runningMax1RM) runningMax1RM = sessionMax1RM;

        if (sessionMaxW > overallMaxWeight) overallMaxWeight = sessionMaxW;
        if (sessionMax1RM > overallMax1RM) overallMax1RM = sessionMax1RM;
        overallVolume += sessionVol;
        totalHardSets += hardSets;

        historyList.add(
          _ExerciseSessionHistory(
            date: date,
            maxWeight: sessionMaxW,
            estimated1RM: sessionMax1RM,
            volume: sessionVol,
            totalSets: sessionSets.length,
            hardSetsCount: hardSets,
            bestSet: bestSet,
            sets: sessionSets,
            isPersonalRecord: isPr,
          ),
        );
      }

      // Calcola progressione percentuale tra la prima sessione utile e l'ultima
      double progressPct = 0.0;
      if (historyList.length >= 2) {
        final first1RM = historyList.first.estimated1RM;
        final last1RM = historyList.last.estimated1RM;
        if (first1RM > 0) {
          progressPct = ((last1RM - first1RM) / first1RM) * 100.0;
        }
      }

      if (mounted) {
        setState(() {
          _history = historyList;
          _allTimeMaxWeight = overallMaxWeight;
          _allTimeMax1RM = overallMax1RM;
          _allTimeVolume = overallVolume;
          _totalSetsAllTime = sets.length;
          _totalHardSetsAllTime = totalHardSets;
          _progressPercentage = progressPct;
          _isLoading = false;
        });
        _animController.forward(from: 0.0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMetricChanged(ChartMetricType metric) {
    if (_selectedMetric == metric) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMetric = metric;
      _selectedPointIndex = -1;
    });
    _animController.forward(from: 0.0);
  }

  List<double> _getChartPoints() {
    switch (_selectedMetric) {
      case ChartMetricType.estimated1RM:
        return _history.map((h) => h.estimated1RM).toList();
      case ChartMetricType.maxWeight:
        return _history.map((h) => h.maxWeight).toList();
      case ChartMetricType.totalVolume:
        return _history.map((h) => h.volume).toList();
    }
  }

  String _formatMetricValue(double val) {
    switch (_selectedMetric) {
      case ChartMetricType.estimated1RM:
      case ChartMetricType.maxWeight:
        return '${val.toStringAsFixed(1)} kg';
      case ChartMetricType.totalVolume:
        return val >= 1000
            ? '${(val / 1000).toStringAsFixed(1)}k kg'
            : '${val.toStringAsFixed(0)} kg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF9700)),
              )
                  : _history.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildExerciseHeroCard(),
                    const SizedBox(height: 16),
                    _buildKpiSection(),
                    const SizedBox(height: 20),
                    _buildInteractiveTrendCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'Storico Sessioni',
                      '${_history.length} allenamenti registrati',
                    ),
                    const SizedBox(height: 12),
                    _buildHistorySessionList(),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFFF9700),
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.muscleGroup.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFF9700),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          if (_history.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF9700), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFFF9700), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_allTimeMax1RM.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      color: Color(0xFFFF9700),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildExerciseHeroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'exercise_${widget.exerciseName}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 60,
                height: 60,
                color: const Color(0xFF242426),
                child: _buildThumbnail(widget.imagePath, 60),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.muscleGroup,
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_progressPercentage != 0.0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _progressPercentage >= 0
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _progressPercentage >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 13,
                              color: _progressPercentage >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${_progressPercentage >= 0 ? '+' : ''}${_progressPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: _progressPercentage >= 0
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSection() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: '1RM STIMATO',
            value: '${_allTimeMax1RM.toStringAsFixed(1)} kg',
            subtitle: 'Best: ${_allTimeMaxWeight.toStringAsFixed(1)} kg reali',
            icon: Icons.emoji_events_rounded,
            accentColor: const Color(0xFFFF9700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'HARD SETS',
            value: '$_totalHardSetsAllTime',
            subtitle: 'su $_totalSetsAllTime serie totali',
            icon: Icons.local_fire_department_rounded,
            accentColor: const Color(0xFFFFB74D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'VOLUME TOT.',
            value: _allTimeVolume >= 1000
                ? '${(_allTimeVolume / 1000).toStringAsFixed(1)}k'
                : _allTimeVolume.toStringAsFixed(0),
            subtitle: 'kg accumulati',
            icon: Icons.fitness_center_rounded,
            accentColor: const Color(0xFFE65100),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTrendCard() {
    final points = _getChartPoints();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Analisi Sovraccarico',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${points.length} punti',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Segmented selector per cambiare la metrica visualizzata sul grafico
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF222224),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildMetricSelectorButton('1RM Stimato', ChartMetricType.estimated1RM),
                _buildMetricSelectorButton('Carico Max', ChartMetricType.maxWeight),
                _buildMetricSelectorButton('Volume', ChartMetricType.totalVolume),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double dx =
              points.length > 1 ? width / (points.length - 1) : 0.0;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (points.length < 2) return;
                  final int index =
                  (details.localPosition.dx / dx).round().clamp(0, points.length - 1);
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedPointIndex =
                    _selectedPointIndex == index ? -1 : index;
                  });
                },
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _chartAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(width, 140),
                        painter: _EnhancedSplinePainter(
                          points: points,
                          selectedIndex: _selectedPointIndex,
                          animationProgress: _chartAnimation.value,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Tooltip interattivo espanso
          if (_selectedPointIndex >= 0 &&
              _selectedPointIndex < _history.length) ...[
            const SizedBox(height: 14),
            _buildInteractiveTooltip(_history[_selectedPointIndex]),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricSelectorButton(String title, ChartMetricType type) {
    final bool isSelected = _selectedMetric == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onMetricChanged(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF9700) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveTooltip(_ExerciseSessionHistory session) {
    final dateStr =
        '${session.date.day.toString().padLeft(2, '0')}/${session.date.month.toString().padLeft(2, '0')}/${session.date.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9700), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                session.isPersonalRecord ? '🔥 NUOVO RECORD' : 'Sessione Utile',
                style: TextStyle(
                  color: session.isPersonalRecord
                      ? const Color(0xFFFF9700)
                      : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _selectedMetric == ChartMetricType.estimated1RM
                    ? '1RM: ${session.estimated1RM.toStringAsFixed(1)} kg'
                    : _selectedMetric == ChartMetricType.maxWeight
                    ? 'Max: ${session.maxWeight.toStringAsFixed(1)} kg'
                    : 'Vol: ${session.volume.toStringAsFixed(0)} kg',
                style: const TextStyle(
                  color: Color(0xFFFF9700),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${session.hardSetsCount} hard sets su ${session.totalSets}',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildHistorySessionList() {
    final reversed = _history.reversed.toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversed.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = reversed[index];
        return _SessionHistoryAccordionCard(session: session);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nessuna sessione registrata',
            style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Esegui questo esercizio in un workout per generare i grafici',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? imagePath, double size) {
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      final trimmed = imagePath.trim();
      if (File(trimmed).existsSync()) {
        return Image.file(File(trimmed), width: size, height: size, fit: BoxFit.cover);
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return Image.network(trimmed, width: size, height: size, fit: BoxFit.cover);
      }
      if (trimmed.startsWith('assets/')) {
        return Image.asset(trimmed, width: size, height: size, fit: BoxFit.cover);
      }
    }
    return const Center(
      child: Icon(Icons.fitness_center_rounded, color: Color(0xFFFF9700), size: 26),
    );
  }
}

/// Card a espansione con dettaglio per serie (warmup vs allenanti)
class _SessionHistoryAccordionCard extends StatefulWidget {
  final _ExerciseSessionHistory session;

  const _SessionHistoryAccordionCard({required this.session});

  @override
  State<_SessionHistoryAccordionCard> createState() =>
      _SessionHistoryAccordionCardState();
}

class _SessionHistoryAccordionCardState
    extends State<_SessionHistoryAccordionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final dateStr =
        '${s.date.day.toString().padLeft(2, '0')}/${s.date.month.toString().padLeft(2, '0')}/${s.date.year}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.isPersonalRecord
              ? const Color(0xFFFF9700).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
          width: s.isPersonalRecord ? 1.2 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _isExpanded = !_isExpanded);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (s.isPersonalRecord) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9700),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'PR',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '1RM: ${s.estimated1RM.toStringAsFixed(1)} kg • ${s.hardSetsCount} hard sets',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Vol: ${s.volume.toStringAsFixed(0)} kg',
                        style: const TextStyle(
                          color: Color(0xFFFF9700),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Max: ${s.maxWeight.toStringAsFixed(1)} kg',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
              // Dettaglio serie a comparsa
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: s.sets.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final set = entry.value;
                    final isWarmup = set.isWarmup ?? false;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isWarmup
                            ? const Color(0xFF202022)
                            : const Color(0xFF2A2A2D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isWarmup
                              ? Colors.transparent
                              : const Color(0xFFFF9700).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isWarmup ? 'W' : '$index',
                            style: TextStyle(
                              color: isWarmup
                                  ? Colors.white38
                                  : const Color(0xFFFF9700),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${set.weight} kg × ${set.reps ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (set.rpe != null && set.rpe! > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '@${set.rpe}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter per tracciare una curva Bézier continua (Spline) con riempimento a gradiente
class _EnhancedSplinePainter extends CustomPainter {
  final List<double> points;
  final int selectedIndex;
  final double animationProgress;

  _EnhancedSplinePainter({
    required this.points,
    this.selectedIndex = -1,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(
        center,
        8,
        Paint()..color = const Color(0xFFFF9700),
      );
      return;
    }

    final double minVal = points.reduce(min);
    final double maxVal = points.reduce(max);
    final double padding = (maxVal == minVal) ? 2.0 : (maxVal - minVal) * 0.15;
    final double bottomVal = minVal - padding;
    final double topVal = maxVal + padding;
    final double range = (topVal == bottomVal) ? 1.0 : (topVal - bottomVal);

    final double dx = size.width / (points.length - 1);

    final Path path = Path();
    final Path fillPath = Path();

    final Paint linePaint = Paint()
      ..color = const Color(0xFFFF9700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFF9700).withValues(alpha: 0.28 * animationProgress),
          const Color(0xFFFF9700).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (int i = 0; i < points.length; i++) {
      final double x = i * dx;
      final double normalized =
          ((points[i] - bottomVal) / range) * animationProgress;
      final double y = size.height - (normalized * (size.height - 16)) - 8;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final double prevX = (i - 1) * dx;
        final double prevNormalized =
            ((points[i - 1] - bottomVal) / range) * animationProgress;
        final double prevY =
            size.height - (prevNormalized * (size.height - 16)) - 8;

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

    // Disegno nodi
    for (int i = 0; i < points.length; i++) {
      final double x = i * dx;
      final double normalized =
          ((points[i] - bottomVal) / range) * animationProgress;
      final double y = size.height - (normalized * (size.height - 16)) - 8;
      final bool isSelected = i == selectedIndex;

      if (isSelected) {
        // Halo di selezione
        canvas.drawCircle(
          Offset(x, y),
          12,
          Paint()..color = const Color(0xFFFF9700).withValues(alpha: 0.3),
        );
        canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = const Color(0xFFFF9700),
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          3.5,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EnhancedSplinePainter oldDelegate) =>
      oldDelegate.points != points ||
          oldDelegate.selectedIndex != selectedIndex ||
          oldDelegate.animationProgress != animationProgress;
}