import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/calendar_models.dart';
import '../../theme/calendar_theme.dart';

typedef OnBarSegmentSelected = void Function(String groupName, double localTopY);

class VerticalMuscleBar extends StatelessWidget {
  final List<ExerciseDetail> exercises;
  final String? selectedGroup;
  final GlobalKey cardStackKey;
  final OnBarSegmentSelected onSegmentSelected;

  const VerticalMuscleBar({
    super.key,
    required this.exercises,
    required this.selectedGroup,
    required this.cardStackKey,
    required this.onSegmentSelected,
  });

  @override
  Widget build(BuildContext context) {
    const double barWidth = 20.0;
    const double barRadius = 8.0;

    if (exercises.isEmpty) {
      return Center(
        child: Container(
          width: barWidth,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(barRadius),
          ),
        ),
      );
    }

    final Map<String, int> muscleSets = {};
    for (final ex in exercises) {
      final macro = CalendarTheme.getNormalizedMacroGroup(ex.muscleGroup);
      muscleSets[macro] = (muscleSets[macro] ?? 0) + ex.sets;
    }

    final sortedEntries = muscleSets.entries.toList()
      ..sort((a, b) => CalendarTheme.getMusclePriority(a.key).compareTo(CalendarTheme.getMusclePriority(b.key)));

    final int totalSets = sortedEntries.fold<int>(0, (sum, e) => sum + e.value);
    if (totalSets == 0) return const SizedBox.shrink();

    return Center(
      child: SizedBox(
        width: barWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sortedEntries.map((entry) {
            final String groupName = entry.key;
            final Color color = CalendarTheme.groupColors[groupName] ?? const Color(0xFFFF9700);
            final bool isSelected = selectedGroup == groupName;

            return Expanded(
              flex: entry.value,
              child: Builder(
                builder: (segmentContext) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();

                      final RenderBox? segmentBox = segmentContext.findRenderObject() as RenderBox?;
                      final RenderBox? cardStackBox = cardStackKey.currentContext?.findRenderObject() as RenderBox?;

                      double targetTopY = 0.0;
                      if (segmentBox != null && cardStackBox != null) {
                        final Offset globalPos = segmentBox.localToGlobal(Offset.zero);
                        final Offset localPos = cardStackBox.globalToLocal(globalPos);
                        final exactTopY = localPos.dy;
                        final segmentHeight = segmentBox.size.height;

                        const double popupHeight = 64.0;
                        final double stackHeight = cardStackBox.size.height;
                        final double maxSafeTop = stackHeight - popupHeight - 55.0;

                        if (exactTopY + popupHeight > maxSafeTop) {
                          final double invertedTop = exactTopY + segmentHeight - popupHeight;
                          targetTopY = invertedTop.clamp(8.0, maxSafeTop);
                        } else {
                          targetTopY = exactTopY.clamp(8.0, maxSafeTop);
                        }
                      }

                      onSegmentSelected(groupName, targetTopY);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(barRadius),
                        border: isSelected ? Border.all(color: Colors.white, width: 2.2) : null,
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 0),
                          ),
                        ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class MuscleBarPopup extends StatelessWidget {
  final String selectedGroup;
  final double topPosition;
  final List<ExerciseDetail> exercises;
  final VoidCallback onClose;

  const MuscleBarPopup({
    super.key,
    required this.selectedGroup,
    required this.topPosition,
    required this.exercises,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, int> muscleSets = {};
    for (final ex in exercises) {
      final macro = CalendarTheme.getNormalizedMacroGroup(ex.muscleGroup);
      muscleSets[macro] = (muscleSets[macro] ?? 0) + ex.sets;
    }
    final int totalSets = muscleSets.values.fold<int>(0, (sum, val) => sum + val);
    final int currentSets = muscleSets[selectedGroup] ?? 0;
    final int percentage = totalSets > 0 ? ((currentSets / totalSets) * 100).round() : 0;
    final Color groupColor = CalendarTheme.groupColors[selectedGroup] ?? const Color(0xFFFF9700);

    return Positioned(
      top: topPosition,
      left: 60.0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: 1.0,
        child: Container(
          width: 175,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF9700), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 12,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: groupColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedGroup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$currentSets',
                    style: const TextStyle(color: Color(0xFFFF9700), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Text('serie totali', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  Text('$percentage%', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}