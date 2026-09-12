import 'package:isar/isar.dart';
import 'routine_template.dart';

part 'session.g.dart';

@collection
class Session {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime date;

  late DateTime startTime;
  DateTime? endTime;

  final routine = IsarLink<RoutineTemplate>();
}
