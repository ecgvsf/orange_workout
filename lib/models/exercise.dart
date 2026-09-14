import 'package:isar/isar.dart';
import '../constants/muscle_group.dart';

part 'exercise.g.dart';

@collection
class Exercise {
  Id id = Isar.autoIncrement;

  @Index()
  late String name;

  /// Gruppo muscolare primario (es. "Petto")
  @Index()
  late String muscleGroup;

  /// Gruppi muscolari sinergici/secondari (es. ["Tricipiti", "Spalle"])
  List<String> secondaryMuscles = [];

  @Index()
  late bool isCompound;

  String? equipment;

  // Getter tipizzati comodi
  @ignore
  MuscleGroup get targetMuscle => MuscleGroup.fromString(muscleGroup);

  @ignore
  List<MuscleGroup> get targetSecondaryMuscles =>
      secondaryMuscles.map(MuscleGroup.fromString).toList();
}
