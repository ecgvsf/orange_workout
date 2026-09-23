import 'dart:io';
import 'package:live_activities/live_activities.dart';

class AppleLiveActivityService {
  static final _liveActivities = LiveActivities();

  static Future<void> init() async {
    // Esci subito se non siamo su un dispositivo Apple
    if (!Platform.isIOS) return;
    await _liveActivities.init(appGroupId: 'group.com.example.orangeWorkout');
  }

  static Future<String?> startRestActivity({
    required String exerciseName,
    required int seconds,
  }) async {
    // Se siamo su Android, non eseguire nulla!
    if (!Platform.isIOS) return null;

    final endTime = DateTime.now().add(Duration(seconds: seconds));
    final String activityId = 'rest_${DateTime.now().millisecondsSinceEpoch}';

    final Map<String, dynamic> activityData = {
      'exerciseName': exerciseName,
      'endTime': endTime.millisecondsSinceEpoch,
    };

    return await _liveActivities.createActivity(
      activityId,
      activityData,
      removeWhenAppIsKilled: true,
      staleIn: Duration(seconds: seconds + 5),
    );
  }

  static Future<void> stopActivity(String activityId) async {
    if (!Platform.isIOS) return;
    await _liveActivities.endActivity(activityId);
  }
}
