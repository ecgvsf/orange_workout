import 'package:isar/isar.dart';

part 'routine_item.g.dart';

@embedded
class RoutineExerciseConfig {
  int exerciseId = 0; // ID di riferimento sul database Isar
  late String exerciseName;
  late String muscleGroup;
  bool isCompound = false;

  int targetSets = 3; // Serie target (es. 3 o 4)
  int minReps = 8; // Ripetizioni minime del range
  int maxReps = 10; // Ripetizioni massime del range
  double targetRpe = 8.0; // Intensità stimata (RPE 7.0 - 10.0)
  int restSeconds = 90; // Tempo di recupero consigliato in secondi
}
