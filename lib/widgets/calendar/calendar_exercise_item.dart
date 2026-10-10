import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/calendar_models.dart';

class CalendarExerciseItem extends StatelessWidget {
  final ExerciseDetail exercise;
  final bool isSelected;
  final bool isSelectionMode;
  final Animation<double> expandAnimation;
  final VoidCallback onTap;

  const CalendarExerciseItem({
    super.key,
    required this.exercise,
    required this.isSelected,
    required this.isSelectionMode,
    required this.expandAnimation,
    required this.onTap,
  });

  Widget _buildThumbnail(String? imagePath, double size) {
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      final trimmed = imagePath.trim();
      if (File(trimmed).existsSync()) {
        return Image.file(File(trimmed), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackIcon());
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return Image.network(trimmed, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackIcon());
      }
      if (trimmed.startsWith('assets/')) {
        return Image.asset(trimmed, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackIcon());
      }
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      color: const Color(0xFF1E1E1E),
      alignment: Alignment.center,
      child: const Icon(Icons.fitness_center_rounded, color: Color(0xFFFF9700), size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: expandAnimation,
      builder: (context, child) {
        final t = expandAnimation.value;
        final double imageSize = 44.0 + (32.0 * t);
        final double imageRadius = 14.0 + (6.0 * t);
        final double itemMarginBottom = 16.0 + (4.0 * t);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: EdgeInsets.only(bottom: itemMarginBottom),
            padding: EdgeInsets.symmetric(
              vertical: 4.0,
              horizontal: isSelectionMode ? 8.0 : 0.0,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF9700).withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isSelected ? Border.all(color: const Color(0xFFFF9700), width: 1.2) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isSelectionMode) ...[
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFFFF9700) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFF9700) : Colors.white38,
                        width: 1.6,
                      ),
                    ),
                    child: isSelected ? const Icon(Icons.check_rounded, size: 14, color: Colors.black) : null,
                  ),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  child: Container(
                    width: imageSize,
                    height: imageSize,
                    color: const Color(0xFF2C2C2E),
                    child: _buildThumbnail(exercise.imagePath, imageSize),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFFF9700) : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (t < 0.15)
                        Container(
                          height: 2.0,
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4.0, right: 75.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9700),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      else
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 2.0,
                                margin: const EdgeInsets.only(right: 8.0, top: 2.0, bottom: 2.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9700).withValues(alpha: t.clamp(0.0, 1.0)),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Series tot: ${exercise.sets}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    ),
                                    Text(
                                      exercise.avgSeconds > 0
                                          ? 'Average time: ${exercise.avgSeconds}s'
                                          : 'Average reps: ${exercise.avgReps}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                                    ),
                                    Text(
                                      'Average weight: ${exercise.avgWeight.toStringAsFixed(1)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white60, fontSize: 12),
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
              ],
            ),
          ),
        );
      },
    );
  }
}