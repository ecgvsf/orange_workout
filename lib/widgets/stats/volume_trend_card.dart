import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modello dati per rappresentare la settimana (supporta anche lo split a cavallo di due mesi)
class MonthlyWeekBarData {
  final double currentMonthVolume;
  final double outsideMonthVolume;
  final String label;

  const MonthlyWeekBarData({
    required this.currentMonthVolume,
    this.outsideMonthVolume = 0.0,
    required this.label,
  });

  double get totalVolume => currentMonthVolume + outsideMonthVolume;
}

class VolumeTrendCard extends StatefulWidget {
  /// Accetta sia una List<double> sia una List<MonthlyWeekBarData>
  final List<dynamic> data;
  final List<String> labels;
  final Animation<double> animation;
  final String weightUnit;

  const VolumeTrendCard({
    super.key,
    required this.data,
    required this.labels,
    required this.animation,
    required this.weightUnit,
  });

  @override
  State<VolumeTrendCard> createState() => _VolumeTrendCardState();
}

class _VolumeTrendCardState extends State<VolumeTrendCard> {
  int _selectedBarIndex = -1;

  /// Normalizza i dati in ingresso convertendo eventuali List<double> in List<MonthlyWeekBarData>
  List<MonthlyWeekBarData> _getNormalizedData() {
    if (widget.data.isEmpty) return [];

    return List.generate(widget.data.length, (index) {
      final item = widget.data[index];
      final label = index < widget.labels.length ? widget.labels[index] : '';

      if (item is MonthlyWeekBarData) {
        return item;
      } else if (item is num) {
        return MonthlyWeekBarData(
          currentMonthVolume: item.toDouble(),
          outsideMonthVolume: 0.0,
          label: label,
        );
      }
      return MonthlyWeekBarData(
        currentMonthVolume: 0.0,
        outsideMonthVolume: 0.0,
        label: label,
      );
    });
  }

  String _getDayOrPeriodLabel(String label) {
    switch (label) {
      case 'Lun':
        return 'Lunedì';
      case 'Mar':
        return 'Martedì';
      case 'Mer':
        return 'Mercoledì';
      case 'Gio':
        return 'Giovedì';
      case 'Ven':
        return 'Venerdì';
      case 'Sab':
        return 'Sabato';
      case 'Dom':
        return 'Domenica';
      default:
        // Se è un range tipo "1-4" o "26-31"
        if (label.contains('-')) {
          return 'Giorni $label';
        }
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<MonthlyWeekBarData> bars = _getNormalizedData();

    // Calcolo della media visualizzata nel badge in alto
    double totalActiveVolume = 0.0;
    int activeCount = 0;
    for (final b in bars) {
      if (b.currentMonthVolume > 0) {
        totalActiveVolume += b.currentMonthVolume;
        activeCount++;
      }
    }
    final double avgVolume =
        activeCount > 0 ? (totalActiveVolume / activeCount) : 0.0;
    final String avgLabel =
        avgVolume >= 1000
            ? '${(avgVolume / 1000).toStringAsFixed(1)}k'
            : avgVolume.toStringAsFixed(0);

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
                    'Volume Sollevato',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tocca una barra per i dettagli',
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
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Media: $avgLabel ${widget.weightUnit}',
                  style: const TextStyle(
                    color: Color(0xFFFF9700),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final double chartWidth = constraints.maxWidth;
              if (bars.isEmpty) {
                return const SizedBox(
                  height: 140,
                  child: Center(
                    child: Text(
                      'Nessun dato registrato',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ),
                );
              }

              final double step = chartWidth / bars.length;

              double popupLeft = 0.0;
              if (_selectedBarIndex >= 0 && _selectedBarIndex < bars.length) {
                final double barCenterX =
                    (_selectedBarIndex * step) + (step / 2);
                popupLeft = (barCenterX - 85).clamp(0.0, chartWidth - 170);
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final double localX = details.localPosition.dx;
                      final int clickedIndex = (localX / step).floor().clamp(
                        0,
                        bars.length - 1,
                      );
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedBarIndex =
                            (_selectedBarIndex == clickedIndex)
                                ? -1
                                : clickedIndex;
                      });
                    },
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: AnimatedBuilder(
                        animation: widget.animation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(chartWidth, 140),
                            painter: _SplitBarChartPainter(
                              data: bars,
                              selectedIndex: _selectedBarIndex,
                              animationProgress: widget.animation.value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_selectedBarIndex >= 0 && _selectedBarIndex < bars.length)
                    Positioned(
                      top: 4,
                      left: popupLeft,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: 1.0,
                        child: _buildBarDetailPopup(bars[_selectedBarIndex]),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Costruzione del Pop-Up interattivo dettagliato
  Widget _buildBarDetailPopup(MonthlyWeekBarData bar) {
    final bool hasSplit = bar.outsideMonthVolume > 0;

    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9700), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getDayOrPeriodLabel(bar.label),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedBarIndex = -1),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Se la barra è sdoppiata, mostra il dettaglio a due colori
          if (hasSplit) ...[
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9700),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${bar.currentMonthVolume.toStringAsFixed(0)} ${widget.weightUnit} (questo mese)',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5A5A5A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${bar.outsideMonthVolume.toStringAsFixed(0)} ${widget.weightUnit} (altro mese)',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 8),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bar.totalVolume > 0 ? bar.totalVolume.toStringAsFixed(0) : '0',
                style: const TextStyle(
                  color: Color(0xFFFF9700),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.weightUnit} totali',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          if (bar.totalVolume == 0)
            const Text(
              'Nessun allenamento',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

/// CustomPainter per il disegno della barra (solida o spezzata a 2 segmenti impilati)
class _SplitBarChartPainter extends CustomPainter {
  final List<MonthlyWeekBarData> data;
  final int selectedIndex;
  final double animationProgress;

  _SplitBarChartPainter({
    required this.data,
    this.selectedIndex = -1,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Trova il massimo considerando l'altezza totale della barra
    double maxVal = 0.0;
    for (final b in data) {
      if (b.totalVolume > maxVal) maxVal = b.totalVolume;
    }
    final double safeMax = maxVal == 0 ? 1.0 : maxVal;

    final double spacing = size.width / data.length;
    final double barWidth = (spacing * 0.52).clamp(10.0, 26.0);
    final double chartHeight = size.height - 24;

    // Pennelli grafici
    final Paint activeMonthPaint =
        Paint()
          ..color = const Color(0xFFFF9700)
          ..style = PaintingStyle.fill;

    final Paint outsideMonthPaint =
        Paint()
          ..color = const Color(0xFF4A4A4A)
          ..style = PaintingStyle.fill;

    final Paint bgColumnPaint =
        Paint()
          ..color = const Color(0xFF242424)
          ..style = PaintingStyle.fill;

    final Paint selectedBorderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    const TextStyle textStyle = TextStyle(color: Colors.white38, fontSize: 10);
    const TextStyle selectedTextStyle = TextStyle(
      color: Color(0xFFFF9700),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    for (int i = 0; i < data.length; i++) {
      final bar = data[i];
      final double x = (i * spacing) + (spacing / 2) - (barWidth / 2);
      final bool isSelected = i == selectedIndex;

      // 1. Canale di sfondo della colonna
      final RRect bgRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(bgRRect, bgColumnPaint);

      // 2. Disegno del volume sollevato
      final double totalBarHeight =
          (bar.totalVolume / safeMax) * chartHeight * animationProgress;

      if (totalBarHeight > 0) {
        final double insideHeight =
            (bar.currentMonthVolume / safeMax) *
            chartHeight *
            animationProgress;
        final double outsideHeight =
            (bar.outsideMonthVolume / safeMax) *
            chartHeight *
            animationProgress;

        canvas.save();
        // Maschera per preservare gli angoli arrotondati della barra
        final RRect barClipRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            chartHeight - totalBarHeight,
            barWidth,
            totalBarHeight,
          ),
          const Radius.circular(6),
        );
        canvas.clipRRect(barClipRRect);

        // Segmento inferiore: mese corrente (Arancione)
        if (insideHeight > 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              chartHeight - insideHeight,
              barWidth,
              insideHeight,
            ),
            activeMonthPaint,
          );
        }

        // Segmento superiore: mese precedente/successivo (Grigio)
        if (outsideHeight > 0) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              chartHeight - totalBarHeight,
              barWidth,
              outsideHeight,
            ),
            outsideMonthPaint,
          );
        }

        canvas.restore();
      }

      // 3. Bordo bianco evidenziato al tocco
      if (isSelected) {
        final RRect selectBorder = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 1, 0, barWidth + 2, chartHeight),
          const Radius.circular(7),
        );
        canvas.drawRRect(selectBorder, selectedBorderPaint);
      }

      // 4. Etichetta asse X
      final textSpan = TextSpan(
        text: bar.label,
        style: isSelected ? selectedTextStyle : textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x + (barWidth / 2) - (textPainter.width / 2), size.height - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplitBarChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.data != data;
}
