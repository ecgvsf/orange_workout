import 'package:flutter/material.dart';

class VolumeChartCard extends StatelessWidget {
  /// Mappa con i volumi (es. in kg o tonnellate) per ciascun giorno da 1 (Lun) a 7 (Dom).
  /// Se per un giorno non c'è allenamento, il valore può essere 0 o assente.
  final Map<int, double> dailyVolumes;
  final String title;

  const VolumeChartCard({
    super.key,
    required this.dailyVolumes,
    this.title = 'Volume',
  });

  @override
  Widget build(BuildContext context) {
    const List<String> weekLetters = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
    final int todayWeekday = DateTime.now().weekday; // 1 = Lun, 7 = Dom

    // Trova il volume massimo per scalare le altezze delle barre
    double maxVolume = 0;
    for (int i = 1; i <= 7; i++) {
      final vol = dailyVolumes[i] ?? 0.0;
      if (vol > maxVolume) maxVolume = vol;
    }
    // Evita la divisione per zero se non ci sono ancora dati
    if (maxVolume == 0) maxVolume = 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Superficie scura coerente con il tema
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Intestazione card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Area del grafico a barre
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 1. Aumentiamo il margine sottratto (es. 28) per dare respiro al testo
                // e usiamo .clamp(0.0, ...) per evitare valori negativi
                final double availableHeight = (constraints.maxHeight - 28)
                    .clamp(0.0, constraints.maxHeight);

                return Column(
                  mainAxisSize:
                      MainAxisSize.min, // Occupa solo lo spazio necessario
                  children: [
                    // Sezione barre verticali
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (index) {
                          final int dayIndex = index + 1;
                          final double volume = dailyVolumes[dayIndex] ?? 0.0;
                          final bool isToday = dayIndex == todayWeekday;
                          final bool hasData = volume > 0;

                          // Calcolo dell'altezza proporzionale
                          final double barHeight =
                              hasData
                                  ? (volume / maxVolume) * availableHeight
                                  : 4.0;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                    // 2. Proteggiamo l'altezza massima con availableHeight
                                    height: barHeight.clamp(
                                      4.0,
                                      availableHeight > 4.0
                                          ? availableHeight
                                          : 4.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          hasData
                                              ? (isToday
                                                  ? const Color(0xFFFF9700)
                                                  : const Color(0xFFFFB74D))
                                              : Colors.white10,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow:
                                          isToday && hasData
                                              ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFFFF9700,
                                                  ).withValues(alpha: 0.35),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                              : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Asse X: Lettere dei giorni della settimana
                    SizedBox(
                      height:
                          16, // 3. Altezza fissa esplicita per evitare oscillazioni di font
                      child: Row(
                        children: List.generate(7, (index) {
                          final bool isToday = (index + 1) == todayWeekday;

                          return Expanded(
                            child: Center(
                              child: Text(
                                weekLetters[index],
                                style: TextStyle(
                                  color:
                                      isToday
                                          ? const Color(0xFFFF9700)
                                          : Colors.white38,
                                  fontSize: 11,
                                  fontWeight:
                                      isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  height:
                                      1.0, // Imposta line-height a 1 per non generare padding invisibile
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
