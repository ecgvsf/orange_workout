import 'package:isar/isar.dart';
import 'session.dart';
import 'exercise.dart';

part 'workout_set.g.dart';

@collection
class WorkoutSet {
  Id id = Isar.autoIncrement;

  int? reps; // Nullabile: nullo se l'esercizio è a tempo
  int? holdSeconds; // Valorizzato se l'esercizio è a tempo (es. 60 per Plank)
  late double weight; // 0.0 per corpo libero puro, >0 per sovraccarico/zavorra

  int? rpe;
  late bool isWarmup;

  final session = IsarLink<Session>();
  final exercise = IsarLink<Exercise>();
}
