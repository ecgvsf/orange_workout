import 'package:flutter/material.dart';

enum TimeFilter { week, month, year }

class CompoundExerciseInfo {
  final String name;
  final String muscle;
  final IconData icon;
  final double pr;
  final String? imagePath;

  const CompoundExerciseInfo({
    required this.name,
    required this.muscle,
    required this.icon,
    required this.pr,
    this.imagePath,
  });
}
