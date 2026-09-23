import 'package:isar/isar.dart';
import 'exercise_type.dart'; // Importa l'enum

part 'routine_item.g.dart';

@embedded
class RoutineExerciseConfig {
  int exerciseId = 0; // ID di riferimento sul database Isar
  late String exerciseName;
  late String muscleGroup;
  bool isCompound = false;

  @enumerated
  ExerciseType exerciseType = ExerciseType.reps; // Tipo di esercizio

  int targetSets = 3; // Serie target (es. 3 o 4)

  // Parametri per esercizi a ripetizioni
  int minReps = 8; // Ripetizioni minime del range
  int maxReps = 10; // Ripetizioni massime del range

  // Parametri per esercizi a tempo
  int minSeconds = 30; // Secondi minimi di tenuta
  int maxSeconds = 45; // Secondi massimi di tenuta

  double targetRpe = 8.0; // Intensità stimata (RPE 7.0 - 10.0)
  int restSeconds = 90; // Tempo di recupero consigliato in secondi
}
