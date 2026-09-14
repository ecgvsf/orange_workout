import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/exercise.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../models/user_profile.dart';

import '../widgets/volume_chart_card.dart';
import '../widgets/muscle_heatmap_card.dart';
import 'routine_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  final Isar? isar;
  const HomeScreen({super.key, this.isar});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _currentWeek;

  // Dati estratti da Isar
  String _userName = 'Andrea';
  Map<int, double> _dailyVolumes = {
    1: 0.0,
    2: 0.0,
    3: 0.0,
    4: 0.0,
    5: 0.0,
    6: 0.0,
    7: 0.0,
  };
  Map<String, int> _weeklyMuscleWorkouts = {};
  bool _isLoading = true;

  StreamSubscription? _setSubscription;
  StreamSubscription? _sessionSubscription;

  final List<String> _dayNames = [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _currentWeek = _generateCurrentWeek(_selectedDate);

    _loadDataFromDatabase();

    // Ricarica automaticamente i dati se vengono salvate nuove sessioni o serie
    if (widget.isar != null) {
      _sessionSubscription = widget.isar!.sessions.watchLazy().listen((_) {
        _loadDataFromDatabase();
      });
      _setSubscription = widget.isar!.workoutSets.watchLazy().listen((_) {
        _loadDataFromDatabase();
      });
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _setSubscription?.cancel();
    super.dispose();
  }

  List<DateTime> _generateCurrentWeek(DateTime referenceDate) {
    final int currentWeekday = referenceDate.weekday;
    final DateTime monday = referenceDate.subtract(
      Duration(days: currentWeekday - 1),
    );
    return List.generate(
      7,
      (index) => DateTime(monday.year, monday.month, monday.day + index),
    );
  }

  /// Recupera profilo, volumi giornalieri e attivazione muscolare settimanale da Isar
  Future<void> _loadDataFromDatabase() async {
    if (widget.isar == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. Lettura profilo utente
    final user = await widget.isar!.userProfiles.where().findFirst();
    final name =
        (user != null && user.name.trim().isNotEmpty) ? user.name : 'Andrea';

    // 2. Calcolo intervallo della settimana visualizzata (da Lunedì 00:00 a Domenica 23:59:59)
    final monday = _currentWeek.first;
    final sunday = _currentWeek.last;
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);
    final endOfWeek = DateTime(
      sunday.year,
      sunday.month,
      sunday.day,
      23,
      59,
      59,
    );

    // 3. Estrai sessioni comprese nella settimana
    final sessions =
        await widget.isar!.sessions
            .filter()
            .dateGreaterThan(startOfWeek.subtract(const Duration(seconds: 1)))
            .and()
            .dateLessThan(endOfWeek.add(const Duration(seconds: 1)))
            .findAll();

    final sessionIds = sessions.map((s) => s.id).toSet();
    final Map<Id, DateTime> sessionDates = {
      for (final s in sessions) s.id: s.date,
    };

    final Map<int, double> tempVolumes = {for (int i = 1; i <= 7; i++) i: 0.0};
    final Map<String, int> tempMuscleCount = {};

    if (sessionIds.isNotEmpty) {
      // 4. Estrazione di tutti i workout sets appartenenti alle sessioni trovate
      final sets =
          await widget.isar!.workoutSets
              .filter()
              .session(
                (q) => q.anyOf(
                  sessionIds,
                  (qSession, Id id) => qSession.idEqualTo(id),
                ),
              )
              .findAll();

      // Per non contare più volte lo stesso muscolo all'interno della stessa singola sessione
      final Map<String, Set<Id>> muscleSessionsMap = {};

      for (final set in sets) {
        if (set.isWarmup) continue;

        await set.session.load();
        await set.exercise.load();

        final sId = set.session.value?.id;
        final sDate = sId != null ? sessionDates[sId] : null;

        // Somma volume (peso * reps) per il giorno della settimana (1..7)
        if (sDate != null) {
          final weekday = sDate.weekday;
          tempVolumes[weekday] =
              (tempVolumes[weekday] ?? 0.0) + (set.weight * set.reps);
        }

        // Raggruppamento per muscoli (primario e secondari)
        final ex = set.exercise.value;
        if (ex != null && sId != null) {
          // Muscolo primario
          final primaryKey = ex.targetMuscle.svgId;
          if (primaryKey.isNotEmpty) {
            muscleSessionsMap.putIfAbsent(primaryKey, () => <Id>{}).add(sId);
          }

          // Muscoli secondari (se presenti)
          for (final secondary in ex.targetSecondaryMuscles) {
            final secKey = secondary.svgId;
            if (secKey.isNotEmpty) {
              muscleSessionsMap.putIfAbsent(secKey, () => <Id>{}).add(sId);
            }
          }
        }
      }

      // Converti in conteggio di sessioni settimanali per distretto muscolare
      muscleSessionsMap.forEach((muscleId, sessionsSet) {
        tempMuscleCount[muscleId] = sessionsSet.length;
      });
    }

    if (mounted) {
      setState(() {
        _userName = name;
        _dailyVolumes = tempVolumes;
        _weeklyMuscleWorkouts = tempMuscleCount;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ciao, $_userName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9700),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings,
                        size: 32,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        // Navigazione Impostazioni
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFFF9700), thickness: 3, height: 1),
              const SizedBox(height: 20),

              // Calendario Settimanale
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:
                    _currentWeek.map((date) {
                      final bool isSelected =
                          date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;

                      final now = DateTime.now();
                      final bool isToday =
                          date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? const Color(0xFFFF9700)
                                      : const Color.fromARGB(0, 30, 30, 30),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.transparent
                                        : (isToday
                                            ? Colors.white54
                                            : Colors.white12),
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  date.day.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.white54,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _dayNames[date.weekday - 1],
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFFF9700), thickness: 3, height: 1),
              const SizedBox(height: 16),

              // Layout Modulare
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF9700),
                          ),
                        )
                        : Column(
                          children: [
                            // 1. CARD IN ALTO: Heatmap a tutta larghezza
                            Expanded(
                              flex: 20,
                              child: MuscleHeatmapCard(
                                title: 'HeatMap',
                                weeklyWorkouts: _weeklyMuscleWorkouts,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 2. SEZIONE INFERIORE: Due colonne
                            Expanded(
                              flex: 12,
                              child: Row(
                                children: [
                                  // Colonna Sinistra: Volume Chart
                                  Expanded(
                                    child: VolumeChartCard(
                                      title: 'Volume',
                                      dailyVolumes: _dailyVolumes,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Colonna Destra: Due card orizzontali (Workout e Routine)
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: _buildHorizontalActionCard(
                                            title: 'Workout',
                                            icon: Icons.fitness_center_rounded,
                                            iconColor: const Color(0xFFFF9700),
                                            onTap: () {
                                              if (widget.isar != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) =>
                                                            ExercisesScreen(
                                                              isar:
                                                                  widget.isar!,
                                                            ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: _buildHorizontalActionCard(
                                            title: 'Routine',
                                            icon: Icons.library_books_rounded,
                                            iconColor: const Color(0xFFFF9700),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const RoutinesScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
              ),

              // Spazio di rispetto per non coprire elementi con la FloatingNavBar
              const SizedBox(height: 35),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalActionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
