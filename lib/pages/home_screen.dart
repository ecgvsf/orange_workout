import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Generazione dei giorni della settimana. In produzione, questi dati
    // verranno popolati dinamicamente calcolando la data odierna.
    final List<Map<String, dynamic>> weekDays = [
      {'day': '31', 'name': 'Lun', 'isCurrent': false},
      {
        'day': '01',
        'name': 'Mar',
        'isCurrent': true,
      }, // Giorno corrente evidenziato
      {'day': '02', 'name': 'Mer', 'isCurrent': false},
      {'day': '03', 'name': 'Gio', 'isCurrent': false},
      {'day': '04', 'name': 'Ven', 'isCurrent': false},
      {'day': '05', 'name': 'Sab', 'isCurrent': false},
      {'day': '06', 'name': 'Dom', 'isCurrent': false},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Sfondo scuro globale
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- INTESTAZIONE ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hi, Andrea', //
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFFFF9700),
                      size: 32,
                    ),
                    onPressed: () {
                      // Logica per aggiungere nuove card statistiche
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- CALENDARIO ADATTIVO ---
              // Sfruttando Expanded, i giorni si distribuiscono equamente su tutta la larghezza[cite: 3]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:
                    weekDays.map((item) {
                      final bool isCurrent = item['isCurrent'];
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color:
                                isCurrent
                                    ? const Color(0xFFFF9700)
                                    : const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isCurrent
                                      ? Colors.transparent
                                      : Colors.white12,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                item['day'],
                                style: TextStyle(
                                  color:
                                      isCurrent ? Colors.black : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['name'],
                                style: TextStyle(
                                  color:
                                      isCurrent
                                          ? Colors.black87
                                          : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 24),

              // --- GRIGLIA ASIMMETRICA NATIVA E RESPONSIVA ---
              // L'uso combinato di Expanded e flex garantisce che la griglia
              // riempia esattamente lo spazio rimanente in altezza e larghezza.
              Expanded(
                child: Row(
                  children: [
                    // Colonna di Sinistra
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Card Alta (Workout)
                          Expanded(
                            flex: 3,
                            child: _buildActionCard(
                              title: 'Workout',
                              subtitle: 'Inizia allenamento',
                              icon: Icons.fitness_center_rounded,
                              iconColor: const Color(0xFFFF9700),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Card Bassa (Routine)
                          Expanded(
                            flex: 2,
                            child: _buildActionCard(
                              title: 'Routine',
                              subtitle: 'Scegli scheda',
                              icon: Icons.list_alt_rounded,
                              iconColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Colonna di Destra
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Card Bassa (Statistiche Rapide)
                          Expanded(
                            flex: 2,
                            child: _buildActionCard(
                              title: 'Volume',
                              subtitle: 'Trend Settimanale',
                              icon: Icons.bar_chart_rounded,
                              iconColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Card Alta (Esercizi/Storico)
                          Expanded(
                            flex: 3,
                            child: _buildActionCard(
                              title: 'Esercizi',
                              subtitle: 'Gestisci libreria',
                              icon: Icons.library_books_rounded,
                              iconColor: const Color(0xFFFF9700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Spazio per impedire alla BottomNavigationBar fluttuante di coprire le card inferiori
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  // Costruttore riutilizzabile per le Card della griglia
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Superficie grigio antracite[cite: 3]
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 38),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
