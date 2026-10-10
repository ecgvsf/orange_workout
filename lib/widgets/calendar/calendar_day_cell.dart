import 'package:flutter/material.dart';
import '../../theme/calendar_theme.dart';

class CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final Color textColor;
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;
  final List<String> muscleGroups;

  const CalendarDayCell({
    super.key,
    required this.day,
    required this.textColor,
    required this.borderColor,
    required this.backgroundColor,
    this.borderWidth = 1.0,
    required this.muscleGroups,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        margin: const EdgeInsets.all(3.0),
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (muscleGroups.isNotEmpty) ...[
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: muscleGroups.take(5).map((muscle) {
                    final dotColor =
                        CalendarTheme.groupColors[muscle] ?? const Color(0xFFFF9700);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      width: 4.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}