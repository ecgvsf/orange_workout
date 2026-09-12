import 'package:isar/isar.dart';
import 'session.dart';
import 'exercise.dart';

part 'workout_set.g.dart';

@collection
class WorkoutSet {
  Id id = Isar.autoIncrement;

  late int reps;
  late double weight;

  int? rpe;
  late bool isWarmup;

  final session = IsarLink<Session>();
  final exercise = IsarLink<Exercise>();
}
