import 'package:isar/isar.dart';
import 'routine_item.dart';

part 'routine_template.g.dart';

@collection
class RoutineTemplate {
  Id id = Isar.autoIncrement;

  late String name;
  String? notes;
  String macroSplit = 'Push'; // Push, Pull, Legs, Upper, Lower, Full Body

  List<RoutineExerciseConfig> exercises = [];
}
