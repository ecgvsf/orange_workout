import 'package:isar/isar.dart';

class ExerciseDetail {
  final Id? exerciseId;
  final String name;
  final String muscleGroup;
  final String? imagePath;
  final int sets;
  final int avgReps;
  final int avgSeconds;
  final double avgWeight;
  final List<Id> setIds;

  const ExerciseDetail({
    this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.imagePath,
    required this.sets,
    required this.avgReps,
    required this.avgSeconds,
    required this.avgWeight,
    required this.setIds,
  });
}

class CalendarWorkoutSummary {
  final Id sessionId;
  final String title;
  final List<ExerciseDetail> exercises;

  const CalendarWorkoutSummary({
    required this.sessionId,
    required this.title,
    required this.exercises,
  });
}