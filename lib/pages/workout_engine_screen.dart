import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../models/workout_set.dart';

class WorkoutEngineScreen extends StatefulWidget {
  final Isar? isar;
  final String routineName;

  const WorkoutEngineScreen({
    super.key,
    this.isar,
    this.routineName = 'Allenamento Libero',
  });

  @override
  State<WorkoutEngineScreen> createState() => _WorkoutEngineScreenState();
}

class _WorkoutEngineScreenState extends State<WorkoutEngineScreen> {
  // Session Timer
  late DateTime _sessionStartTime;
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;

  // Rest Timer
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isRestActive = false;

  // Dati Esercizio Corrente
  String _currentExerciseName = 'Panca Piana Bilanciere';
  double _selectedWeight = 80.0;
  int _selectedReps = 8;
  int _selectedRpe = 8;
  bool _isWarmup = false;

  // Registro serie della sessione corrente
  final List<Map<String, dynamic>> _completedSets = [];

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _startSessionTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _sessionDuration = DateTime.now().difference(_sessionStartTime);
      });
    });
  }

  void _startRestTimer(int durationSeconds) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = durationSeconds;
      _isRestActive = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 1) {
        setState(() {
          _restSecondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isRestActive = false;
        });
      }
    });
  }

  double get _currentTonnage {
    return _completedSets.fold(0.0, (acc, item) {
      if (item['isWarmup'] == true) return acc;
      return acc + ((item['weight'] as double) * (item['reps'] as int));
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    final hours = d.inHours > 0 ? '${d.inHours}:' : '';
    return '$hours$minutes:$seconds';
  }

  void _logCurrentSet() {
    setState(() {
      _completedSets.insert(0, {
        'exercise': _currentExerciseName,
        'weight': _selectedWeight,
        'reps': _selectedReps,
        'rpe': _selectedRpe,
        'isWarmup': _isWarmup,
        'timestamp': DateTime.now(),
      });
    });

    // Avvia recupero consigliato (90s predefiniti)
    _startRestTimer(90);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 30,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.routineName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFFF9700),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_sessionDuration),
                  style: const TextStyle(
                    color: Color(0xFFFF9700),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Vol: ${_currentTonnage.toStringAsFixed(0)} kg',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF9700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _confirmFinishWorkout(),
              child: const Text(
                'FINE',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- TIMER RECUPERO (SE ATTIVO) ---
            if (_isRestActive) _buildRestTimerBar(),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // --- SELECTOR ESERCIZIO ---
                    _buildExerciseHeader(),
                    const SizedBox(height: 18),

                    // --- MANOPOLA CIRCOLARE PESO (DIAL) ---
                    _buildWeightDial(),
                    const SizedBox(height: 20),

                    // --- CONTROLLO REPETIZIONI & RPE ---
                    _buildRepsAndRpeRow(),
                    const SizedBox(height: 16),

                    // --- TOGGLE RISCALDAMENTO & BOTTONE SALVA SERIE ---
                    _buildWarmupAndSaveRow(),
                    const SizedBox(height: 24),

                    // --- LOG DELLE SERIE CONCLUSE ---
                    _buildCompletedSetsLog(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestTimerBar() {
    final double percent = (_restSecondsRemaining / 90).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: Color(0xFFFF9700),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Recupero: ${_restSecondsRemaining}s',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 6,
                backgroundColor: const Color(0xFF141414),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF9700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _restSecondsRemaining += 30),
            child: const Text(
              '+30s',
              style: TextStyle(color: Color(0xFFFFB74D), fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => setState(() => _isRestActive = false),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Esercizio in corso',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                _currentExerciseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: Color(0xFFFF9700),
            ),
            onPressed: () => _pickExerciseDialog(),
          ),
        ],
      ),
    );
  }

  // Manopola rotante con GestureDetector angolare
  Widget _buildWeightDial() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'SELEZIONA CARICO',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 210,
            height: 210,
            child: GestureDetector(
              onPanUpdate: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final center = const Offset(105, 105);
                final touchPosition = details.localPosition;
                final angle = math.atan2(
                  touchPosition.dy - center.dy,
                  touchPosition.dx - center.dx,
                );

                // Normalizza angolo da 0 a 2PI partendo dall'alto
                double normalized = angle + (math.pi / 2);
                if (normalized < 0) normalized += 2 * math.pi;

                // Mappa l'angolo su scala 0-200 kg con scatti di 0.5kg
                final weightValue = ((normalized / (2 * math.pi)) * 160).clamp(
                  0.0,
                  200.0,
                );
                setState(() {
                  _selectedWeight = (weightValue * 2).round() / 2;
                });
              },
              child: CustomPaint(
                painter: _CircularDialPainter(
                  weight: _selectedWeight,
                  maxWeight: 160.0,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedWeight.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'KG',
                        style: TextStyle(
                          color: Color(0xFFFF9700),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Pulsanti fini - / +
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepButton(
                '-2.5',
                () => setState(
                  () => _selectedWeight = math.max(0, _selectedWeight - 2.5),
                ),
              ),
              const SizedBox(width: 10),
              _buildStepButton(
                '-0.5',
                () => setState(
                  () => _selectedWeight = math.max(0, _selectedWeight - 0.5),
                ),
              ),
              const SizedBox(width: 20),
              _buildStepButton(
                '+0.5',
                () => setState(() => _selectedWeight += 0.5),
              ),
              const SizedBox(width: 10),
              _buildStepButton(
                '+2.5',
                () => setState(() => _selectedWeight += 2.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRepsAndRpeRow() {
    return Row(
      children: [
        // Repetizioni
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'RIPETIZIONI',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFFFF9700),
                      ),
                      onPressed:
                          () => setState(
                            () =>
                                _selectedReps = math.max(1, _selectedReps - 1),
                          ),
                    ),
                    Text(
                      '$_selectedReps',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFFFF9700),
                      ),
                      onPressed: () => setState(() => _selectedReps++),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // RPE (Sforzo Percepito)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'FATICA (RPE)',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFFFFB74D),
                      ),
                      onPressed:
                          () => setState(
                            () => _selectedRpe = math.max(5, _selectedRpe - 1),
                          ),
                    ),
                    Text(
                      '$_selectedRpe',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFFFFB74D),
                      ),
                      onPressed:
                          () => setState(
                            () => _selectedRpe = math.min(10, _selectedRpe + 1),
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
  }

  Widget _buildWarmupAndSaveRow() {
    return Row(
      children: [
        // Toggle Warmup
        GestureDetector(
          onTap: () => setState(() => _isWarmup = !_isWarmup),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color:
                  _isWarmup ? const Color(0xFF2C2C2E) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isWarmup ? const Color(0xFFFF9700) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isWarmup
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: _isWarmup ? const Color(0xFFFF9700) : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Warmup',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Pulsante Registra Serie
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _logCurrentSet,
              icon: const Icon(
                Icons.check_rounded,
                color: Colors.black,
                size: 22,
              ),
              label: const Text(
                'COMPLETA SERIE',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedSetsLog() {
    if (_completedSets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Nessuna serie registrata. Seleziona il carico e tocca "Completa Serie".',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'LOG SERIE RECENTI',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._completedSets.asMap().entries.map((entry) {
          final idx = _completedSets.length - entry.key;
          final s = entry.value;
          final bool isW = s['isWarmup'] == true;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isW
                            ? Colors.white10
                            : const Color(0xFFFF9700).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isW ? 'W' : 'SET $idx',
                    style: TextStyle(
                      color: isW ? Colors.white54 : const Color(0xFFFF9700),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s['exercise'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${s['weight']} kg × ${s['reps']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'RPE ${s['rpe']}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _pickExerciseDialog() {
    final list = [
      'Panca Piana Bilanciere',
      'Squat Bilanciere',
      'Trazioni alla Sbarra',
      'Military Press',
      'Rematore Bilanciere',
      'French Press EZ',
      'Alzate Laterali',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (c, i) {
            return ListTile(
              title: Text(list[i], style: const TextStyle(color: Colors.white)),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFFFF9700),
                size: 16,
              ),
              onTap: () {
                setState(() => _currentExerciseName = list[i]);
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  void _confirmFinishWorkout() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Terminare la sessione?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Hai completato ${_completedSets.length} serie per un tonnellaggio totale di ${_currentTonnage.toStringAsFixed(0)} kg in ${_formatDuration(_sessionDuration)}.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Annulla',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9700),
                ),
                onPressed: () async {
                  // Salvataggio su Isar se fornito
                  if (widget.isar != null && _completedSets.isNotEmpty) {
                    final session =
                        Session()
                          ..date = DateTime.now()
                          ..startTime = _sessionStartTime
                          ..endTime = DateTime.now();

                    await widget.isar!.writeTxn(() async {
                      await widget.isar!.sessions.put(session);
                    });
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Salva e Chiudi',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// Custom Painter per la ghiera circolare graduata
class _CircularDialPainter extends CustomPainter {
  final double weight;
  final double maxWeight;

  _CircularDialPainter({required this.weight, required this.maxWeight});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;

    final bgPaint =
        Paint()
          ..color = const Color(0xFF141414)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final progressPaint =
        Paint()
          ..color = const Color(0xFFFF9700)
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // Disegna anello di fondo
    canvas.drawCircle(center, radius, bgPaint);

    // Disegna arco attivo proporzionale al peso
    final double sweepAngle = (weight / maxWeight) * (2 * math.pi);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle.clamp(0.0, 2 * math.pi),
      false,
      progressPaint,
    );

    // Tacche graduate secondarie
    final tickPaint =
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 1.5;

    for (int i = 0; i < 24; i++) {
      final double angle = (i / 24) * 2 * math.pi;
      final p1 = Offset(
        center.dx + (radius - 18) * math.cos(angle),
        center.dy + (radius - 18) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 12) * math.cos(angle),
        center.dy + (radius - 12) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularDialPainter oldDelegate) {
    return oldDelegate.weight != weight;
  }
}
