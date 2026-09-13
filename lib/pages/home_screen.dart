import 'package:flutter/material.dart';
import '../widgets/volume_chart_card.dart';
import '../widgets/muscle_heatmap_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _selectedDate;
  late List<DateTime> _currentWeek;

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
  }

  List<DateTime> _generateCurrentWeek(DateTime referenceDate) {
    final int currentWeekday = referenceDate.weekday;
    final DateTime monday = referenceDate.subtract(
      Duration(days: currentWeekday - 1),
    );
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
                  const Text(
                    'Hi, Andrea',
                    style: TextStyle(
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
              const Divider(color: Color(0xFFFF9700), thickness: 1, height: 1),
              const SizedBox(height: 16),

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
                                Text(
                                  date.day.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.white54,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFFF9700), thickness: 1, height: 1),
              const SizedBox(height: 16),

              // Layout Modulare
              Expanded(
                child: Column(
                  children: [
                    // 1. CARD IN ALTO: Heatmap a tutta larghezza
                    Expanded(
                      flex: 20,
                      child: MuscleHeatmapCard(
                        title: 'HeatMap',
                        weeklyWorkouts: const {
                          'chest': 3,
                          'deltoidi': 2,
                          'dorsali': 1,
                          'bicipiti': 1,
                          'tricipiti': 2,
                          'quadricipiti': 2,
                          'femorali': 2,
                          'polpacci': 1,
                          'trapezio': 3,
                          'lombari': 1,
                        },
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
                              dailyVolumes: const {
                                1: 4200.0,
                                2: 0.0,
                                3: 5600.0,
                                4: 0.0,
                                5: 6100.0,
                                6: 3400.0,
                                7: 0.0,
                              },
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
                                      // Azione Avvia Workout
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
                                      // Azione Gestione Routine
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
          mainAxisAlignment:
              MainAxisAlignment
                  .center, // Centra orizzontalmente tutto il gruppo (icona + testo)
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
