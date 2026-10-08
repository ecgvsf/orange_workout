import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

enum BodyGender { male, female }

class MuscleHeatmapCard extends StatefulWidget {
  final String title;
  final Map<String, int> weeklyWorkouts;
  final BodyGender initialGender;

  const MuscleHeatmapCard({
    super.key,
    this.title = 'Mappa Muscolare',
    required this.weeklyWorkouts,
    this.initialGender = BodyGender.male,
  });

  @override
  State<MuscleHeatmapCard> createState() => _MuscleHeatmapCardState();
}

class _MuscleHeatmapCardState extends State<MuscleHeatmapCard> {
  late BodyGender _selectedGender;
  String? _svgString;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.initialGender;
    _generateHeatmapSvg();
  }

  @override
  void didUpdateWidget(covariant MuscleHeatmapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsUpdate = false;

    // Se il genere in ingresso è cambiato (dalla HomeScreen)
    if (oldWidget.initialGender != widget.initialGender) {
      _selectedGender = widget.initialGender;
      needsUpdate = true;
    }

    // Se i dati degli allenamenti sono cambiati
    if (oldWidget.weeklyWorkouts != widget.weeklyWorkouts) {
      needsUpdate = true;
    }

    // Rigenera l'SVG solo se c'è stata una modifica
    if (needsUpdate) {
      _generateHeatmapSvg();
    }
  }

  String _getFrequencyColor(int count) {
    if (count <= 0) return '#3A3A3C'; // Inattivo
    if (count >= 1 && count < 3) return '#FFB74D'; // 1x
    if (count == 3 || count == 4) return '#FF9700'; // 3x
    return '#E65100'; // 5x+
  }

  Future<void> _generateHeatmapSvg() async {
    setState(() => _isLoading = true);

    final assetPath =
    _selectedGender == BodyGender.male
        ? 'assets/images/male_muscles.svg'
        : 'assets/images/female_muscles.svg';

    String rawSvg = await rootBundle.loadString(assetPath);

    // 1. Uniforma la base neutra (testa, mani, piedi)
    rawSvg = rawSvg.replaceAllMapped(
      RegExp(r'<g class="altro"[^>]*fill="[^"]*"'),
          (match) => '<g class="altro" fill="#2C2C2E"',
    );

    const allMuscles = [
      'chest',
      'dorsali',
      'deltoidi',
      'bicipiti',
      'tricipiti',
      'addominali-centrali',
      'addominali-laterali',
      'quadricipiti',
      'femorali',
      'glutei',
      'polpacci',
      'lombari',
      'trapezio',
      'avambracci',
      'adduttori',
      'abduttori',
      'soleo',
    ];

    // 2. Sostituisce l'attributo fill sul tag <g> o <path> corrispondente
    for (final muscleId in allMuscles) {
      final int workoutCount = widget.weeklyWorkouts[muscleId] ?? 0;
      final String targetColor = _getFrequencyColor(workoutCount);

      // Cerca il tag (sia <g> che <path>) con id esatto
      final regex = RegExp('(<(?:g|path)\\s+[^>]*id="$muscleId"[^>]*?)fill="[^"]*"');
      rawSvg = rawSvg.replaceAllMapped(regex, (match) {
        return '${match.group(1)}fill="$targetColor"';
      });

      // Cerca i sottogruppi (fascicoli muscolari) con ID del tipo 'muscleId-...' (es. trapezio-sinistro)
      final subRegex = RegExp('(<(?:g|path)\\s+[^>]*id="$muscleId[-_][^"]*"[^>]*?)fill="[^"]*"');
      rawSvg = rawSvg.replaceAllMapped(subRegex, (match) {
        return '${match.group(1)}fill="$targetColor"';
      });
    }

    if (mounted) {
      setState(() {
        _svgString = rawSvg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Area Contenuto: SVG a sinistra (flessibile) e Legenda a destra (verticale)
          Expanded(
            child: Row(
              children: [
                // SVG Heatmap
                Expanded(
                  child:
                      _isLoading || _svgString == null
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF9700),
                            ),
                          )
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              return SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: SvgPicture.string(
                                  _svgString!,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                ),
                              );
                            },
                          ),
                ),
                const SizedBox(width: 12),

                // Legenda Disposta in Verticale
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVerticalLegendItem(const Color(0xFF3A3A3C), '0x'),
                    const SizedBox(height: 16),
                    _buildVerticalLegendItem(const Color(0xFFFFB74D), '1x'),
                    const SizedBox(height: 16),
                    _buildVerticalLegendItem(const Color(0xFFFF9700), '3x'),
                    const SizedBox(height: 16),
                    _buildVerticalLegendItem(const Color(0xFFE65100), '5x+'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderButton({
    required BodyGender gender,
    required IconData icon,
  }) {
    final bool isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        if (_selectedGender != gender) {
          setState(() => _selectedGender = gender);
          _generateHeatmapSvg();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF9700) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : Colors.white54,
        ),
      ),
    );
  }

  Widget _buildVerticalLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
