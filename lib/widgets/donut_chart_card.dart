import 'dart:math' as math;
import 'package:flutter/material.dart';

class MuscleSplitData {
  final String label;
  final int sets;
  final Color color;

  const MuscleSplitData({
    required this.label,
    required this.sets,
    required this.color,
  });
}

class SplitDonutChartCard extends StatelessWidget {
  final String title;
  final List<MuscleSplitData> data;

  const SplitDonutChartCard({
    super.key,
    this.title = 'Split Muscolare',
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final int totalSets = data.fold(0, (sum, item) => sum + item.sets);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header compatto
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
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Area suddivisa verticalmente tra Donut e Legenda
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxAvailableForDonut = constraints.maxHeight - 92;
                final double chartDiameter = maxAvailableForDonut.clamp(
                  64.0,
                  160.0,
                );

                return Column(
                  children: [
                    // 1. Donut Chart centrato
                    Center(
                      child: SizedBox(
                        width: chartDiameter,
                        height: chartDiameter,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size(chartDiameter, chartDiameter),
                              painter: _DonutChartPainter(
                                data: data,
                                totalSets: totalSets,
                                strokeWidth: 25.0,
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$totalSets',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: (chartDiameter * 0.22).clamp(
                                      14.0,
                                      20.0,
                                    ),
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'serie',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: (chartDiameter * 0.12).clamp(
                                      9.0,
                                      11.0,
                                    ),
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. Legenda centrata orizzontalmente
                    Expanded(
                      child: Center(
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children:
                                data.map((item) {
                                  final double percentage =
                                      totalSets > 0
                                          ? (item.sets / totalSets) * 100
                                          : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 1.0,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: item.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.label,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${item.sets} (${percentage.toStringAsFixed(0)}%)',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
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

class _DonutChartPainter extends CustomPainter {
  final List<MuscleSplitData> data;
  final int totalSets;
  final double strokeWidth;

  _DonutChartPainter({
    required this.data,
    required this.totalSets,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final Paint backgroundPaint =
        Paint()
          ..color = Colors.white10
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    if (totalSets == 0) {
      canvas.drawOval(rect, backgroundPaint);
      return;
    }

    double startAngle = -math.pi / 2;

    for (final item in data) {
      if (item.sets <= 0) continue;
      final double sweepAngle = (item.sets / totalSets) * 2 * math.pi;

      final Paint slicePaint =
          Paint()
            ..color = item.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, slicePaint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.totalSets != totalSets || oldDelegate.data != data;
}
