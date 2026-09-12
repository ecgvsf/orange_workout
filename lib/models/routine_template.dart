import 'package:isar/isar.dart';
import 'exercise.dart';

part 'routine_template.g.dart';

@collection
class RoutineTemplate {
  Id id = Isar.autoIncrement;

  late String name;
  String? notes;

  final exercises = IsarLinks<Exercise>();
}
