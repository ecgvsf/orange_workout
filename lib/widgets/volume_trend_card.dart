import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VolumeTrendCard extends StatefulWidget {
  final List<double> data;
  final List<String> labels;
  final Animation<double> animation;

  const VolumeTrendCard({
    super.key,
    required this.data,
    required this.labels,
    required this.animation,
  });

  @override
  State<VolumeTrendCard> createState() => _VolumeTrendCardState();
}

class _VolumeTrendCardState extends State<VolumeTrendCard> {
  int _selectedBarIndex = -1;

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
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Text(
                  'Media: 6.2k/die',
                  style: TextStyle(
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
              final double step = chartWidth / widget.data.length;

              double popupLeft = 0.0;
              if (_selectedBarIndex >= 0 &&
                  _selectedBarIndex < widget.data.length) {
                final double barCenterX =
                    (_selectedBarIndex * step) + (step / 2);
                popupLeft = (barCenterX - 75).clamp(0.0, chartWidth - 150);
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
                        widget.data.length - 1,
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
                            painter: _BarChartPainter(
                              data: widget.data,
                              labels: widget.labels,
                              selectedIndex: _selectedBarIndex,
                              animationProgress: widget.animation.value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_selectedBarIndex >= 0 &&
                      _selectedBarIndex < widget.data.length)
                    Positioned(
                      top: 6,
                      left: popupLeft,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: 1.0,
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
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
                                    _getDayOrPeriodLabel(
                                      widget.labels[_selectedBarIndex],
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap:
                                        () => setState(
                                          () => _selectedBarIndex = -1,
                                        ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white38,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    widget.data[_selectedBarIndex] > 0
                                        ? widget.data[_selectedBarIndex]
                                            .toStringAsFixed(0)
                                        : '0',
                                    style: const TextStyle(
                                      color: Color(0xFFFF9700),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'kg totali',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.data[_selectedBarIndex] == 0)
                                const Text(
                                  'Giorno di riposo',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontStyle: FontStyle.italic,
                                  ),
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
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int selectedIndex;
  final double animationProgress;

  _BarChartPainter({
    required this.data,
    required this.labels,
    this.selectedIndex = -1,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double maxVal = data.reduce(max);
    final double safeMax = maxVal == 0 ? 1 : maxVal;
    final double spacing = size.width / data.length;
    final double barWidth = (spacing * 0.5).clamp(8.0, 24.0);

    final Paint inactivePaint =
        Paint()
          ..color = const Color(0xFF2C2C2E)
          ..style = PaintingStyle.fill;

    final Paint activePaint =
        Paint()
          ..color = const Color(0xFFFF9700)
          ..style = PaintingStyle.fill;

    final Paint selectedBorderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    const textStyle = TextStyle(color: Colors.white38, fontSize: 10);
    const selectedTextStyle = TextStyle(
      color: Color(0xFFFF9700),
      fontSize: 11,
      fontWeight: FontWeight.bold,
    );

    for (int i = 0; i < data.length; i++) {
      final double val = data[i];
      final double barHeight =
          (val / safeMax) * (size.height - 24) * animationProgress;
      final double x = (i * spacing) + (spacing / 2) - (barWidth / 2);
      final double y = (size.height - 24) - barHeight;
      final bool isSelected = i == selectedIndex;

      final RRect backgroundRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, size.height - 24),
        const Radius.circular(6),
      );
      canvas.drawRRect(backgroundRRect, inactivePaint);

      if (barHeight > 0) {
        final RRect activeRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(6),
        );
        canvas.drawRRect(activeRRect, activePaint);
      }

      if (isSelected) {
        final RRect selectedRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 1, 0, barWidth + 2, size.height - 24),
          const Radius.circular(7),
        );
        canvas.drawRRect(selectedRRect, selectedBorderPaint);
      }

      final textSpan = TextSpan(
        text: labels[i],
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
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.data != data ||
      oldDelegate.labels != labels;
}
