import 'package:isar/isar.dart';

part 'exercise.g.dart';

@collection
class Exercise {
  Id id = Isar.autoIncrement;

  late String name;
  late String muscleGroup;

  @Index()
  late bool isCompound;

  String? equipment;
}
